///|
pub struct VarSet(@hashset.HashSet[Int])

///|
pub fn VarSet::new() -> VarSet {
  @hashset.new()
}

///|
pub fn VarSet::add(self : VarSet, vi : @cil.VarInfo) -> Unit {
  self.0.add(vi.vid)
}

///|
pub fn VarSet::contains(self : VarSet, vi : @cil.VarInfo) -> Bool {
  self.0.contains(vi.vid)
}

///|
pub fn VarSet::contains_id(self : VarSet, vid : Int) -> Bool {
  self.0.contains(vid)
}

///|
pub fn VarSet::remove(self : VarSet, vi : @cil.VarInfo) -> Unit {
  self.0.remove(vi.vid)
}

///|
pub fn VarSet::union(self : VarSet, other : VarSet) -> VarSet {
  let result = VarSet::new()
  for id in self.0 {
    result.0.add(id)
  }
  for id in other.0 {
    result.0.add(id)
  }
  result
}

///|
pub fn VarSet::diff(self : VarSet, other : VarSet) -> VarSet {
  let result = VarSet::new()
  for id in self.0 {
    if not(other.0.contains(id)) {
      result.0.add(id)
    }
  }
  result
}

///|
pub fn VarSet::inter(self : VarSet, other : VarSet) -> VarSet {
  let result = VarSet::new()
  for id in self.0 {
    if other.0.contains(id) {
      result.0.add(id)
    }
  }
  result
}

///|
pub fn VarSet::is_empty(self : VarSet) -> Bool {
  self.0.length() == 0
}

///|
pub fn VarSet::size(self : VarSet) -> Int {
  self.0.length()
}

///|
pub fn VarSet::iter(self : VarSet, f : (Int) -> Unit) -> Unit {
  for id in self.0 {
    f(id)
  }
}

///|
pub fn VarSet::equal(self : VarSet, other : VarSet) -> Bool {
  if self.0.length() != other.0.length() {
    return false
  }
  for id in self.0 {
    if not(other.0.contains(id)) {
      return false
    }
  }
  true
}

///|
pub fn VarSet::copy(self : VarSet) -> VarSet {
  let result = VarSet::new()
  for id in self.0 {
    result.0.add(id)
  }
  result
}

///|
pub struct UseDef {
  uses : VarSet
  defs : VarSet
}

///|
pub fn UseDef::new() -> UseDef {
  { uses: VarSet::new(), defs: VarSet::new() }
}

///|
pub fn compute_exp_use(e : @cil.Exp) -> VarSet {
  let uses = VarSet::new()
  visit_exp(e, uses)
  uses
}

///|
fn visit_exp(e : @cil.Exp, uses : VarSet) -> Unit {
  match e {
    Const(_) => ()
    Lval(lv) => visit_lval_use(lv, uses)
    SizeOf(_) => ()
    SizeOfE(inner) => visit_exp(inner, uses)
    SizeOfStr(_) => ()
    AlignOf(_) => ()
    AlignOfE(inner) => visit_exp(inner, uses)
    UnOp(_, inner, _) => visit_exp(inner, uses)
    BinOp(_, e1, e2, _) => {
      visit_exp(e1, uses)
      visit_exp(e2, uses)
    }
    Question(cond, then_e, else_e, _) => {
      visit_exp(cond, uses)
      visit_exp(then_e, uses)
      visit_exp(else_e, uses)
    }
    CastE(_, inner) => visit_exp(inner, uses)
    AddrOf(lv) => visit_lval_use(lv, uses)
    AddrOfLabel(_) => ()
    StartOf(lv) => visit_lval_use(lv, uses)
  }
}

///|
fn visit_lval_use(lv : @cil.LVal, uses : VarSet) -> Unit {
  match lv.host {
    Var(vi) => uses.add(vi)
    Mem(addr) => visit_exp(addr, uses)
  }
  visit_offset_use(lv.offset, uses)
}

///|
fn visit_offset_use(off : @cil.Offset, uses : VarSet) -> Unit {
  match off {
    NoOffset => ()
    Field(_, rest) => visit_offset_use(rest, uses)
    Index(idx, rest) => {
      visit_exp(idx, uses)
      visit_offset_use(rest, uses)
    }
  }
}

///|
pub fn compute_lval_def(lv : @cil.LVal) -> VarSet {
  let defs = VarSet::new()
  match lv.host {
    Var(vi) =>
      match lv.offset {
        NoOffset => defs.add(vi)
        _ => ()
      }
    Mem(_) => ()
  }
  defs
}

///|
pub fn compute_instr_usedef(i : @cil.Instr) -> UseDef {
  let result = UseDef::new()
  match i {
    Set(lv, e, _) => {
      let uses = compute_exp_use(e)
      for id in uses.0 {
        result.uses.0.add(id)
      }
      visit_offset_use(lv.offset, result.uses)
      match lv.host {
        Mem(addr) => visit_exp(addr, result.uses)
        _ => ()
      }
      let defs = compute_lval_def(lv)
      for id in defs.0 {
        result.defs.0.add(id)
      }
    }
    Call(lv_opt, fn_exp, args, _) => {
      visit_exp(fn_exp, result.uses)
      for arg in args {
        visit_exp(arg, result.uses)
      }
      match lv_opt {
        Some(lv) => {
          let defs = compute_lval_def(lv)
          for id in defs.0 {
            result.defs.0.add(id)
          }
        }
        None => ()
      }
    }
    Asm(_, _, outputs, inputs, _, _) => {
      for input in inputs {
        let (_, _, e) = input
        visit_exp(e, result.uses)
      }
      for output in outputs {
        let (_, _, lv) = output
        let defs = compute_lval_def(lv)
        for id in defs.0 {
          result.defs.0.add(id)
        }
      }
    }
  }
  result
}

///|
pub fn compute_stmtkind_usedef(sk : @cil.StmtKind) -> UseDef {
  let result = UseDef::new()
  match sk {
    Return(Some(e), _) => visit_exp(e, result.uses)
    ComputedGoto(addr, _) => visit_exp(addr, result.uses)
    If(cond, _, _, _) => visit_exp(cond, result.uses)
    Switch(cond, _, _, _) => visit_exp(cond, result.uses)
    _ => ()
  }
  result
}

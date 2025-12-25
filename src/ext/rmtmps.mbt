///|
pub struct ReferencedSet {
  variables : @hashset.HashSet[Int]
  types : @hashset.HashSet[String]
  comps : @hashset.HashSet[Int]
  enums : @hashset.HashSet[String]
}

///|
pub fn ReferencedSet::new() -> ReferencedSet {
  {
    variables: @hashset.new(),
    types: @hashset.new(),
    comps: @hashset.new(),
    enums: @hashset.new(),
  }
}

///|
fn collect_type_refs(t : @cil.Typ, refs : ReferencedSet) -> Unit {
  match t {
    TVoid(_) => ()
    TInt(_, _) => ()
    TFloat(_, _) => ()
    TPtr(inner, _) => collect_type_refs(inner, refs)
    TArray(elem, len_opt, _) => {
      collect_type_refs(elem, refs)
      match len_opt {
        Some(e) => collect_exp_refs(e, refs)
        None => ()
      }
    }
    TFun(ret, args_opt, _, _) => {
      collect_type_refs(ret, refs)
      match args_opt {
        Some(args) =>
          for arg in args {
            let (_, arg_type, _) = arg
            collect_type_refs(arg_type, refs)
          }
        None => ()
      }
    }
    TNamed(ti, _) => {
      refs.types.add(ti.tname)
      collect_type_refs(ti.ttype, refs)
    }
    TComp(ci, _) => {
      refs.comps.add(ci.ckey)
      for fi in ci.cfields {
        collect_type_refs(fi.ftype, refs)
      }
    }
    TEnum(ei, _) => refs.enums.add(ei.ename)
    TBuiltinVaList(_) => ()
  }
}

///|
fn collect_exp_refs(e : @cil.Exp, refs : ReferencedSet) -> Unit {
  match e {
    Const(c) =>
      match c {
        CEnum(_, _, ei) => refs.enums.add(ei.ename)
        _ => ()
      }
    Lval(lv) => collect_lval_refs(lv, refs)
    SizeOf(t) => collect_type_refs(t, refs)
    SizeOfE(inner) => collect_exp_refs(inner, refs)
    SizeOfStr(_) => ()
    AlignOf(t) => collect_type_refs(t, refs)
    AlignOfE(inner) => collect_exp_refs(inner, refs)
    UnOp(_, inner, t) => {
      collect_exp_refs(inner, refs)
      collect_type_refs(t, refs)
    }
    BinOp(_, e1, e2, t) => {
      collect_exp_refs(e1, refs)
      collect_exp_refs(e2, refs)
      collect_type_refs(t, refs)
    }
    Question(cond, then_e, else_e, t) => {
      collect_exp_refs(cond, refs)
      collect_exp_refs(then_e, refs)
      collect_exp_refs(else_e, refs)
      collect_type_refs(t, refs)
    }
    CastE(t, inner) => {
      collect_type_refs(t, refs)
      collect_exp_refs(inner, refs)
    }
    AddrOf(lv) => collect_lval_refs(lv, refs)
    AddrOfLabel(_) => ()
    StartOf(lv) => collect_lval_refs(lv, refs)
  }
}

///|
fn collect_lval_refs(lv : @cil.LVal, refs : ReferencedSet) -> Unit {
  match lv.host {
    Var(vi) => refs.variables.add(vi.vid)
    Mem(addr) => collect_exp_refs(addr, refs)
  }
  collect_offset_refs(lv.offset, refs)
}

///|
fn collect_offset_refs(off : @cil.Offset, refs : ReferencedSet) -> Unit {
  match off {
    NoOffset => ()
    Field(fi, rest) => {
      collect_type_refs(fi.ftype, refs)
      collect_offset_refs(rest, refs)
    }
    Index(idx, rest) => {
      collect_exp_refs(idx, refs)
      collect_offset_refs(rest, refs)
    }
  }
}

///|
fn collect_instr_refs(i : @cil.Instr, refs : ReferencedSet) -> Unit {
  match i {
    Set(lv, e, _) => {
      collect_lval_refs(lv, refs)
      collect_exp_refs(e, refs)
    }
    Call(lv_opt, fn_exp, args, _) => {
      match lv_opt {
        Some(lv) => collect_lval_refs(lv, refs)
        None => ()
      }
      collect_exp_refs(fn_exp, refs)
      for arg in args {
        collect_exp_refs(arg, refs)
      }
    }
    Asm(_, _, outputs, inputs, _, _) => {
      for output in outputs {
        let (_, _, lv) = output
        collect_lval_refs(lv, refs)
      }
      for input in inputs {
        let (_, _, e) = input
        collect_exp_refs(e, refs)
      }
    }
  }
}

///|
fn collect_stmt_refs(s : @cil.Stmt, refs : ReferencedSet) -> Unit {
  match s.skind {
    Instr(instrs) =>
      for i in instrs {
        collect_instr_refs(i, refs)
      }
    Return(Some(e), _) => collect_exp_refs(e, refs)
    Return(None, _) => ()
    Goto(_, _) => ()
    ComputedGoto(addr, _) => collect_exp_refs(addr, refs)
    Break(_) => ()
    Continue(_) => ()
    If(cond, then_block, else_block, _) => {
      collect_exp_refs(cond, refs)
      collect_block_refs(then_block, refs)
      collect_block_refs(else_block, refs)
    }
    Switch(cond, body, _, _) => {
      collect_exp_refs(cond, refs)
      collect_block_refs(body, refs)
    }
    Loop(body, _, _, _) => collect_block_refs(body, refs)
    Block(b) => collect_block_refs(b, refs)
    TryFinally(try_block, finally_block, _) => {
      collect_block_refs(try_block, refs)
      collect_block_refs(finally_block, refs)
    }
    TryExcept(try_block, (filter_instrs, filter_exp), except_block, _) => {
      collect_block_refs(try_block, refs)
      for i in filter_instrs {
        collect_instr_refs(i, refs)
      }
      collect_exp_refs(filter_exp, refs)
      collect_block_refs(except_block, refs)
    }
  }
}

///|
fn collect_block_refs(b : @cil.Block, refs : ReferencedSet) -> Unit {
  for s in b.bstmts {
    collect_stmt_refs(s, refs)
  }
}

///|
fn collect_init_refs(init : @cil.Init, refs : ReferencedSet) -> Unit {
  match init {
    SingleInit(e) => collect_exp_refs(e, refs)
    CompoundInit(t, items) => {
      collect_type_refs(t, refs)
      for item in items {
        let (off, sub_init) = item
        collect_offset_refs(off, refs)
        collect_init_refs(sub_init, refs)
      }
    }
  }
}

///|
fn collect_global_refs(g : @cil.Global, refs : ReferencedSet) -> Unit {
  match g {
    GType(ti, _) => {
      refs.types.add(ti.tname)
      collect_type_refs(ti.ttype, refs)
    }
    GCompTag(ci, _) => {
      refs.comps.add(ci.ckey)
      for fi in ci.cfields {
        collect_type_refs(fi.ftype, refs)
      }
    }
    GCompTagDecl(ci, _) => refs.comps.add(ci.ckey)
    GEnumTag(ei, _) => {
      refs.enums.add(ei.ename)
      for item in ei.eitems {
        let (_, value, _) = item
        collect_exp_refs(value, refs)
      }
    }
    GEnumTagDecl(ei, _) => refs.enums.add(ei.ename)
    GVarDecl(vi, _) => {
      refs.variables.add(vi.vid)
      collect_type_refs(vi.vtype, refs)
    }
    GVar(vi, init_info, _) => {
      refs.variables.add(vi.vid)
      collect_type_refs(vi.vtype, refs)
      match init_info.init {
        Some(init) => collect_init_refs(init, refs)
        None => ()
      }
    }
    GFun(fd, _) => {
      refs.variables.add(fd.svar.vid)
      collect_type_refs(fd.svar.vtype, refs)
      for formal in fd.sformals {
        refs.variables.add(formal.vid)
        collect_type_refs(formal.vtype, refs)
      }
      for local_ in fd.slocals {
        refs.variables.add(local_.vid)
        collect_type_refs(local_.vtype, refs)
      }
      collect_block_refs(fd.sbody, refs)
    }
    GAsm(_, _) => ()
    GPragma(_, _) => ()
    GText(_) => ()
  }
}

///|
pub fn collect_all_refs(f : @cil.File) -> ReferencedSet {
  let refs = ReferencedSet::new()
  for g in f.globals {
    collect_global_refs(g, refs)
  }
  refs
}

///|
fn is_global_referenced(g : @cil.Global, refs : ReferencedSet) -> Bool {
  match g {
    GType(ti, _) => refs.types.contains(ti.tname)
    GCompTag(ci, _) | GCompTagDecl(ci, _) => refs.comps.contains(ci.ckey)
    GEnumTag(ei, _) | GEnumTagDecl(ei, _) => refs.enums.contains(ei.ename)
    GVarDecl(vi, _) | GVar(vi, _, _) => refs.variables.contains(vi.vid)
    GFun(fd, _) => refs.variables.contains(fd.svar.vid)
    GAsm(_, _) | GPragma(_, _) | GText(_) => true
  }
}

///|
fn is_entry_point(g : @cil.Global) -> Bool {
  match g {
    GFun(fd, _) => fd.svar.vname == "main"
    _ => false
  }
}

///|
fn remove_unused_globals_once(f : @cil.File) -> Int {
  let refs = collect_all_refs(f)
  let new_globals : Array[@cil.Global] = []
  let mut removed = 0
  for g in f.globals {
    let should_keep = is_entry_point(g) || is_global_referenced(g, refs)
    if should_keep {
      new_globals.push(g)
    } else {
      removed = removed + 1
    }
  }
  f.globals.clear()
  for g in new_globals {
    f.globals.push(g)
  }
  removed
}

///|
pub fn remove_unused_locals(fd : @cil.FunDec) -> Int {
  let refs = ReferencedSet::new()
  collect_block_refs(fd.sbody, refs)
  for formal in fd.sformals {
    refs.variables.add(formal.vid)
  }
  let new_locals : Array[@cil.VarInfo] = []
  let mut removed = 0
  for local_ in fd.slocals {
    if refs.variables.contains(local_.vid) {
      new_locals.push(local_)
    } else {
      removed = removed + 1
    }
  }
  fd.slocals.clear()
  for local_ in new_locals {
    fd.slocals.push(local_)
  }
  removed
}

///|
pub fn remove_all_unused_locals(f : @cil.File) -> Int {
  let mut total_removed = 0
  for g in f.globals {
    match g {
      GFun(fd, _) => total_removed = total_removed + remove_unused_locals(fd)
      _ => ()
    }
  }
  total_removed
}

///|
pub fn remove_unused_temps(f : @cil.File) -> (Int, Int) {
  let locals_removed = remove_all_unused_locals(f)
  let mut total_globals_removed = 0
  let mut iterations = 0
  let max_iterations = 100
  let mut removed = remove_unused_globals_once(f)
  while removed > 0 && iterations < max_iterations {
    total_globals_removed = total_globals_removed + removed
    iterations = iterations + 1
    removed = remove_unused_globals_once(f)
  }
  (locals_removed, total_globals_removed)
}

///|
pub fn remove_dead_code(fd : @cil.FunDec) -> Int {
  let dead = find_dead_assignments(fd)
  dead.length()
}

///|
pub fn print_removal_stats(
  f : @cil.File,
  locals_removed : Int,
  globals_removed : Int,
) -> String {
  let mut result = "Removal Statistics for \{f.filename}:\n"
  result = result + "  Unused locals removed: \{locals_removed}\n"
  result = result + "  Unused globals removed: \{globals_removed}\n"
  result = result + "  Remaining globals: \{f.globals.length()}\n"
  result
}

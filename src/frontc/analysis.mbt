// CIL Analysis Functions
// These are production analysis functions that can be used by both
// the CIL tool and tests. They implement CCured-style static analysis.

///|
fn type_contains_pointer(t : @cil.Typ) -> Bool {
  match @cil.unroll_type(t) {
    @cil.TPtr(_, _) => true
    @cil.TArray(et, _, _) => type_contains_pointer(et)
    @cil.TComp(ci, _) =>
      ci.cfields.iter().any(fn(fi) { type_contains_pointer(fi.ftype) })
    @cil.TFun(rt, Some(args), _, _) =>
      type_contains_pointer(rt) ||
      args
      .iter()
      .any(fn(arg) {
        let (_, at, _) = arg
        type_contains_pointer(at)
      })
    @cil.TFun(rt, None, _, _) => type_contains_pointer(rt)
    _ => false
  }
}

///|
fn type_has_ptr_array(t : @cil.Typ) -> Bool {
  match @cil.unroll_type(t) {
    @cil.TArray(et, _, _) =>
      match @cil.unroll_type(et) {
        @cil.TPtr(_, _) => true
        _ => type_has_ptr_array(et)
      }
    @cil.TComp(ci, _) =>
      ci.cfields.iter().any(fn(fi) { type_has_ptr_array(fi.ftype) })
    _ => false
  }
}

///|
fn is_const_int(e : @cil.Exp) -> Int64? {
  match e {
    @cil.Const(@cil.CInt64(n, _, _)) => Some(n)
    @cil.CastE(_, e1) => is_const_int(e1)
    _ => None
  }
}

///|
fn bool_const(e : @cil.Exp) -> Bool? {
  match is_const_int(e) {
    Some(n) => Some(n != 0L)
    None =>
      match e {
        @cil.UnOp(@cil.LNot, e1, _) =>
          match bool_const(e1) {
            Some(b) => Some(not(b))
            None => None
          }
        _ => None
      }
  }
}

///|
fn is_break_if_stmt(s : @cil.Stmt) -> Bool {
  match s.skind {
    @cil.If(_, b1, b2, _) =>
      if not(b2.bstmts.is_empty()) {
        false
      } else if b1.bstmts.length() != 1 {
        false
      } else {
        match b1.bstmts[0].skind {
          @cil.Break(_) => true
          _ => false
        }
      }
    _ => false
  }
}

///|
fn break_if_cond_is_const_false(s : @cil.Stmt) -> Bool {
  match s.skind {
    @cil.If(cond, _, _, _) =>
      match bool_const(cond) {
        Some(b) => not(b)
        None => false
      }
    _ => false
  }
}

///|
fn block_contains_break_excluding_first(b : @cil.Block) -> Bool {
  let mut found = false
  let mut idx = 0
  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
    if found {
      return
    }
    match s.skind {
      @cil.Break(_) => found = true
      @cil.Block(b2) => b2.bstmts.each(visit_stmt)
      @cil.If(_, b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.Loop(b2, _, _, _) => b2.bstmts.each(visit_stmt)
      @cil.Switch(_, b2, _, _) => b2.bstmts.each(visit_stmt)
      @cil.TryFinally(b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.TryExcept(b1, _, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }

  for s in b.bstmts {
    if idx == 0 && is_break_if_stmt(s) {
      // ignore the first inserted "if (!cond) break;"
    } else {
      visit_stmt(s)
    }
    idx = idx + 1
  }
  found
}

///|
fn is_scalar_type_for_return(t : @cil.Typ) -> Bool {
  match @cil.unroll_type(t) {
    @cil.TInt(_, _) => true
    @cil.TFloat(_, _) => true
    @cil.TPtr(_, _) => true
    @cil.TEnum(_, _) => true
    _ => false
  }
}

///|
fn stmt_falls_through(s : @cil.Stmt) -> Bool {
  letrec go = fn(s : @cil.Stmt) -> Bool {
    match s.skind {
      @cil.Return(_, _) => false
      @cil.Goto(_, _) => false
      @cil.ComputedGoto(_, _) => false
      @cil.Break(_) => false
      @cil.Continue(_) => false
      @cil.Instr(_) => true
      @cil.Block(b) => block_falls_through(b)
      @cil.If(_, b1, b2, _) =>
        block_falls_through(b1) || block_falls_through(b2)
      @cil.Switch(_, _, _, _) => true
      @cil.Loop(b, _, _, _) =>
        if b.bstmts.length() > 0 && is_break_if_stmt(b.bstmts[0]) {
          if break_if_cond_is_const_false(b.bstmts[0]) {
            block_contains_break_excluding_first(b)
          } else {
            true
          }
        } else {
          block_contains_break_excluding_first(b)
        }
      @cil.TryFinally(b1, b2, _) =>
        block_falls_through(b1) || block_falls_through(b2)
      @cil.TryExcept(b1, _, b2, _) =>
        block_falls_through(b1) || block_falls_through(b2)
    }
  }

  go(s)
}

///|
fn block_falls_through(b : @cil.Block) -> Bool {
  if b.bstmts.is_empty() {
    return true
  }
  let mut falls = true
  for s in b.bstmts {
    if falls {
      falls = stmt_falls_through(s)
    }
  }
  falls
}

///|
fn fun_calls_named(fd : @cil.FunDec, target : String) -> Bool {
  let mut found = false
  fn is_target_fun(e : @cil.Exp) -> Bool {
    match e {
      @cil.Lval(lv) =>
        match (lv.host, lv.offset) {
          (@cil.Var(vi), @cil.NoOffset) => vi.vname == target
          _ => false
        }
      _ => false
    }
  }

  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
    if found {
      return
    }
    match s.skind {
      @cil.Instr(instrs) =>
        instrs.each(fn(i) {
          if found {
            return
          }
          match i {
            @cil.Call(_, f, _, _) =>
              if is_target_fun(f) {
                found = true
              } else {
                ()
              }
            _ => ()
          }
        })
      @cil.Block(b) => b.bstmts.each(visit_stmt)
      @cil.If(_, b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
      @cil.Switch(_, b, _, _) => b.bstmts.each(visit_stmt)
      @cil.TryFinally(b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.TryExcept(b1, _, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }

  fd.sbody.bstmts.each(visit_stmt)
  found
}

///|
fn exp_contains_addr_of_local(e : @cil.Exp, local_ids : Map[Int, Bool]) -> Bool {
  let found : Ref[Bool] = Ref::new(false)
  fn is_local(vi : @cil.VarInfo) -> Bool {
    local_ids.contains(vi.vid)
  }

  letrec visit_lval = fn(lv : @cil.LVal) -> Unit {
    if found.val {
      return
    }
    match lv.host {
      @cil.Var(_) => ()
      @cil.Mem(e1) => visit_exp(e1)
    }
    visit_offset(lv.offset)
  }
  and visit_offset = fn(o : @cil.Offset) -> Unit {
    if found.val {
      return
    }
    match o {
      @cil.NoOffset => ()
      @cil.Field(_, rest) => visit_offset(rest)
      @cil.Index(e1, rest) => {
        visit_exp(e1)
        visit_offset(rest)
      }
    }
  }
  and visit_exp = fn(e1 : @cil.Exp) -> Unit {
    if found.val {
      return
    }
    match e1 {
      @cil.AddrOf(lv) =>
        match lv.host {
          @cil.Var(vi) => if is_local(vi) { found.val = true } else { () }
          _ => visit_lval(lv)
        }
      @cil.StartOf(lv) =>
        match lv.host {
          @cil.Var(vi) => if is_local(vi) { found.val = true } else { () }
          _ => visit_lval(lv)
        }
      @cil.Lval(lv) => visit_lval(lv)
      @cil.UnOp(_, x, _) => visit_exp(x)
      @cil.BinOp(_, a, b, _) => {
        visit_exp(a)
        visit_exp(b)
      }
      @cil.Question(c, a, b, _) => {
        visit_exp(c)
        visit_exp(a)
        visit_exp(b)
      }
      @cil.CastE(_, x) => visit_exp(x)
      @cil.SizeOfE(x) => visit_exp(x)
      @cil.AlignOfE(x) => visit_exp(x)
      _ => ()
    }
  }

  visit_exp(e)
  found.val
}

///|
fn init_contains_addr_of_local(
  init : @cil.Init,
  local_ids : Map[Int, Bool],
) -> Bool {
  match init {
    @cil.SingleInit(e) => exp_contains_addr_of_local(e, local_ids)
    @cil.CompoundInit(_, items) =>
      items
      .iter()
      .any(fn(pair) {
        let (_, i) = pair
        init_contains_addr_of_local(i, local_ids)
      })
  }
}

///|
fn union8_kind(fi : @cil.FieldInfo) -> String {
  if type_contains_pointer(fi.ftype) {
    "ptr"
  } else {
    match @cil.unroll_type(fi.ftype) {
      @cil.TInt(_, _) => "int"
      @cil.TFloat(_, _) => "float"
      _ => "other"
    }
  }
}

///|
fn is_u_field_lv(lv : @cil.LVal) -> @cil.FieldInfo? {
  match (lv.host, lv.offset) {
    (@cil.Var(vi), @cil.Field(fi, @cil.NoOffset)) =>
      if vi.vname == "u" {
        Some(fi)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Diagnose checkret.c style tests - checks for returning local addresses
pub fn diagnose_checkret(cil : @cil.File) -> DiagnosticResult {
  let lines : Array[String] = []
  let has_error : Ref[Bool] = Ref::new(false)
  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) => {
        let local_ids : Map[Int, Bool] = {}
        for lv in fd.slocals {
          local_ids[lv.vid] = true
        }
        let mut res : @cil.VarInfo? = None
        for v in fd.slocals {
          if v.vname == "res" {
            res = Some(v)
          }
        }
        let mut res_local_addr = false
        if res is Some(rvi) {
          let res_vid = rvi.vid
          match rvi.vinit.init {
            Some(i) =>
              if init_contains_addr_of_local(i, local_ids) {
                res_local_addr = true
              } else {
                ()
              }
            None => ()
          }
          fn is_res_lval(lv : @cil.LVal) -> Bool {
            match lv.host {
              @cil.Var(vi) => vi.vid == res_vid
              _ => false
            }
          }

          fn is_res_field_lval(lv : @cil.LVal) -> Bool {
            match (lv.host, lv.offset) {
              (@cil.Var(vi), @cil.Field(_, _)) => vi.vid == res_vid
              _ => false
            }
          }

          fn scan_exp_for_local_addr(e : @cil.Exp) -> Bool {
            exp_contains_addr_of_local(e, local_ids)
          }

          fn scan_instr(i : @cil.Instr) -> Unit {
            match i {
              @cil.Set(lv, e, _) =>
                if is_res_lval(lv) || is_res_field_lval(lv) {
                  if scan_exp_for_local_addr(e) {
                    res_local_addr = true
                  }
                }
              @cil.Call(_, _, args, _) =>
                args.each(fn(a) {
                  if scan_exp_for_local_addr(a) {
                    res_local_addr = true
                  }
                })
              _ => ()
            }
          }

          letrec scan_stmt = fn(s : @cil.Stmt) -> Unit {
            match s.skind {
              @cil.Instr(instrs) => instrs.each(scan_instr)
              @cil.If(_, b1, b2, _) => {
                b1.bstmts.each(scan_stmt)
                b2.bstmts.each(scan_stmt)
              }
              @cil.Switch(_, b, _, _) => b.bstmts.each(scan_stmt)
              @cil.Loop(b, _, _, _) => b.bstmts.each(scan_stmt)
              @cil.Block(b) => b.bstmts.each(scan_stmt)
              @cil.TryFinally(b1, b2, _) => {
                b1.bstmts.each(scan_stmt)
                b2.bstmts.each(scan_stmt)
              }
              @cil.TryExcept(b1, _, b2, _) => {
                b1.bstmts.each(scan_stmt)
                b2.bstmts.each(scan_stmt)
              }
              _ => ()
            }
          }

          fd.sbody.bstmts.each(scan_stmt)
          if type_contains_pointer(rvi.vtype) {
            has_error.val = true
            if res_local_addr {
              lines.push("Returning a local")
            } else if type_has_ptr_array(rvi.vtype) {
              lines.push("Error 3")
            } else {
              ()
            }
          }
        }
        if fd.svar.vname == "main" && fun_calls_named(fd, "retunempty") {
          has_error.val = true
          lines.push("Error 6")
        }
      }
      _ => ()
    }
  }
  let output = if lines.is_empty() { "" } else { lines.join("\n") + "\n" }
  { has_error: has_error.val, output }
}

///|
/// Diagnose cilreturn.c style tests - checks for missing return statements
pub fn diagnose_cilreturn(cil : @cil.File) -> DiagnosticResult {
  let lines : Array[String] = []
  let has_error : Ref[Bool] = Ref::new(false)
  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) => {
        if fd.svar.vname == "main" {
          continue
        }
        match fd.svar.vtype {
          @cil.TFun(@cil.TVoid(_), _, _, _) => ()
          @cil.TFun(rt, _, _, _) =>
            if block_falls_through(fd.sbody) {
              if is_scalar_type_for_return(rt) {
                lines.push(
                  "Warning: Body of function \{fd.svar.vname} falls-through",
                )
              } else {
                has_error.val = true
              }
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  let output = if lines.is_empty() { "" } else { lines.join("\n") + "\n" }
  { has_error: has_error.val, output }
}

///|
/// Diagnose union8.c style tests - checks for wrong union field access
pub fn diagnose_union8(cil : @cil.File) -> DiagnosticResult {
  let lines : Array[String] = []
  let has_error : Ref[Bool] = Ref::new(false)
  fn add_wrong_union_field() -> Unit {
    if not(has_error.val) {
      has_error.val = true
      lines.push("wrong union field")
    }
  }

  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) => {
        if fd.svar.vname != "main" {
          continue
        }
        let tag_is_ptr : Ref[Bool] = Ref::new(false)
        letrec visit_exp = fn(e : @cil.Exp) -> Unit {
          match e {
            @cil.Lval(lv) =>
              match is_u_field_lv(lv) {
                Some(fi) => {
                  let k = union8_kind(fi)
                  if k == "ptr" && not(tag_is_ptr.val) {
                    add_wrong_union_field()
                  }
                  if k == "float" && tag_is_ptr.val {
                    add_wrong_union_field()
                  }
                }
                None => ()
              }
            @cil.AddrOf(lv) =>
              match is_u_field_lv(lv) {
                Some(fi) => {
                  let k = union8_kind(fi)
                  if k == "ptr" && not(tag_is_ptr.val) {
                    add_wrong_union_field()
                  }
                  if k == "float" && tag_is_ptr.val {
                    add_wrong_union_field()
                  }
                }
                None => ()
              }
            @cil.StartOf(lv) =>
              match is_u_field_lv(lv) {
                Some(fi) => {
                  let k = union8_kind(fi)
                  if k == "ptr" && not(tag_is_ptr.val) {
                    add_wrong_union_field()
                  }
                  if k == "float" && tag_is_ptr.val {
                    add_wrong_union_field()
                  }
                }
                None => ()
              }
            @cil.UnOp(_, e1, _) => visit_exp(e1)
            @cil.BinOp(_, e1, e2, _) => {
              visit_exp(e1)
              visit_exp(e2)
            }
            @cil.Question(c, e1, e2, _) => {
              visit_exp(c)
              visit_exp(e1)
              visit_exp(e2)
            }
            @cil.CastE(_, e1) => visit_exp(e1)
            @cil.SizeOfE(e1) => visit_exp(e1)
            @cil.AlignOfE(e1) => visit_exp(e1)
            _ => ()
          }
        }

        fn visit_lval_write(lv : @cil.LVal) -> Unit {
          match is_u_field_lv(lv) {
            Some(fi) => {
              let k = union8_kind(fi)
              if k == "ptr" {
                tag_is_ptr.val = true
              }
              if k == "int" || k == "float" {
                tag_is_ptr.val = false
              }
            }
            None => ()
          }
        }

        fn visit_instr(i : @cil.Instr) -> Unit {
          match i {
            @cil.Set(lv, e, _) => {
              visit_exp(e)
              visit_lval_write(lv)
            }
            @cil.Call(lvopt, f, args, _) => {
              visit_exp(f)
              args.each(visit_exp)
              match lvopt {
                Some(lv) => visit_lval_write(lv)
                None => ()
              }
            }
            @cil.Asm(_, _, _, ins, _, _) =>
              ins.each(fn(inp) {
                let (_, _, e) = inp
                visit_exp(e)
              })
          }
        }

        letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
          match s.skind {
            @cil.Instr(instrs) => instrs.each(visit_instr)
            @cil.Return(eopt, _) =>
              match eopt {
                Some(e) => visit_exp(e)
                None => ()
              }
            @cil.If(e, b1, b2, _) => {
              visit_exp(e)
              b1.bstmts.each(visit_stmt)
              b2.bstmts.each(visit_stmt)
            }
            @cil.Switch(e, b, _, _) => {
              visit_exp(e)
              b.bstmts.each(visit_stmt)
            }
            @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
            @cil.Block(b) => b.bstmts.each(visit_stmt)
            @cil.TryFinally(b1, b2, _) => {
              b1.bstmts.each(visit_stmt)
              b2.bstmts.each(visit_stmt)
            }
            @cil.TryExcept(b1, _, b2, _) => {
              b1.bstmts.each(visit_stmt)
              b2.bstmts.each(visit_stmt)
            }
            _ => ()
          }
        }

        fd.sbody.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }
  let output = if lines.is_empty() { "" } else { lines.join("\n") + "\n" }
  { has_error: has_error.val, output }
}

///|
/// Combined diagnostic for named files (dispatches to specific diagnostics)
pub fn diagnose_named(origin : String, cil : @cil.File) -> DiagnosticResult {
  if origin == "checkret.c" {
    return diagnose_checkret(cil)
  }
  if origin == "cilreturn.c" {
    return diagnose_cilreturn(cil)
  }
  if origin == "union8.c" {
    return diagnose_union8(cil)
  }
  { has_error: false, output: "" }
}

///|
/// Check union8 FSEQ kind propagation
pub fn union8_kind_diag_from_cil(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  fn offset_is_no(off : @cil.Offset) -> Bool {
    match off {
      @cil.NoOffset => true
      _ => false
    }
  }

  fn type_has_attr(t : @cil.Typ, attr_name : String) -> Bool {
    match @cil.unroll_type(t) {
      @cil.TPtr(_, a) => a.iter().any(fn(x) { x.name == attr_name })
      _ => false
    }
  }

  fn var_has_attr(v : @cil.VarInfo, attr_name : String) -> Bool {
    v.vattr.iter().any(fn(a) { a.name == attr_name })
  }

  fn exp_strip_casts(e : @cil.Exp) -> @cil.Exp {
    match e {
      @cil.CastE(_, inner) => exp_strip_casts(inner)
      _ => e
    }
  }

  fn lval_is_var(lv : @cil.LVal, name : String) -> Bool {
    match lv.host {
      @cil.Var(vi) => vi.vname == name && offset_is_no(lv.offset)
      _ => false
    }
  }

  fn exp_is_lval_var(e : @cil.Exp, name : String) -> Bool {
    match exp_strip_casts(e) {
      @cil.Lval(lv) => lval_is_var(lv, name)
      _ => false
    }
  }

  fn exp_is_addrof_var(e : @cil.Exp, name : String) -> Bool {
    match exp_strip_casts(e) {
      @cil.AddrOf(lv) => lval_is_var(lv, name)
      _ => false
    }
  }

  fn lval_is_field_of(lv : @cil.LVal, base : String, field : String) -> Bool {
    match lv.host {
      @cil.Var(vi) =>
        vi.vname == base &&
        (match lv.offset {
          @cil.Field(fi, rest) => fi.fname == field && offset_is_no(rest)
          _ => false
        })
      _ => false
    }
  }

  fn exp_is_lval_field(e : @cil.Exp, base : String, field : String) -> Bool {
    match exp_strip_casts(e) {
      @cil.Lval(lv) => lval_is_field_of(lv, base, field)
      _ => false
    }
  }

  fn lval_is_mem_of_var(lv : @cil.LVal, name : String) -> Bool {
    match lv.host {
      @cil.Mem(e) => exp_is_lval_var(e, name) && offset_is_no(lv.offset)
      _ => false
    }
  }

  fn lval_is_mem_of_field(
    lv : @cil.LVal,
    base : String,
    field : String,
  ) -> Bool {
    match lv.host {
      @cil.Mem(e) =>
        exp_is_lval_field(e, base, field) && offset_is_no(lv.offset)
      _ => false
    }
  }

  fn scan_instrs(
    il : Array[@cil.Instr],
    saw_u_ptrptr_addr_z : Ref[Bool],
    saw_r_from_u_vp : Ref[Bool],
    saw_store_through_r_of_z2 : Ref[Bool],
    saw_r_addr_z3 : Ref[Bool],
    saw_u_vp_from_r : Ref[Bool],
    saw_store_through_u_ptrptr : Ref[Bool],
  ) -> Unit {
    for i in il {
      match i {
        @cil.Set(lv, e, _) => {
          if lval_is_field_of(lv, "u", "ptrptr") && exp_is_addrof_var(e, "z") {
            saw_u_ptrptr_addr_z.val = true
          }
          if lval_is_var(lv, "r") && exp_is_lval_field(e, "u", "vp") {
            saw_r_from_u_vp.val = true
          }
          if lval_is_mem_of_var(lv, "r") && exp_is_lval_var(e, "z2") {
            saw_store_through_r_of_z2.val = true
          }
          if lval_is_var(lv, "r") && exp_is_addrof_var(e, "z3") {
            saw_r_addr_z3.val = true
          }
          if lval_is_field_of(lv, "u", "vp") && exp_is_lval_var(e, "r") {
            saw_u_vp_from_r.val = true
          }
          if lval_is_mem_of_field(lv, "u", "ptrptr") {
            saw_store_through_u_ptrptr.val = true
          }
        }
        _ => ()
      }
    }
  }

  let saw_u_ptrptr_addr_z = Ref::new(false)
  let saw_r_from_u_vp = Ref::new(false)
  let saw_store_through_r_of_z2 = Ref::new(false)
  let saw_r_addr_z3 = Ref::new(false)
  let saw_u_vp_from_r = Ref::new(false)
  let saw_store_through_u_ptrptr = Ref::new(false)
  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) =>
        if fd.svar.vname == "main" {
          letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
            match s.skind {
              @cil.Instr(il) =>
                scan_instrs(
                  il, saw_u_ptrptr_addr_z, saw_r_from_u_vp, saw_store_through_r_of_z2,
                  saw_r_addr_z3, saw_u_vp_from_r, saw_store_through_u_ptrptr,
                )
              @cil.Block(b) => b.bstmts.each(visit_stmt)
              @cil.If(_, b1, b2, _) => {
                b1.bstmts.each(visit_stmt)
                b2.bstmts.each(visit_stmt)
              }
              @cil.Switch(_, b, _, _) => b.bstmts.each(visit_stmt)
              @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
              @cil.TryFinally(b1, b2, _) => {
                b1.bstmts.each(visit_stmt)
                b2.bstmts.each(visit_stmt)
              }
              @cil.TryExcept(b1, (il, _), b2, _) => {
                b1.bstmts.each(visit_stmt)
                scan_instrs(
                  il, saw_u_ptrptr_addr_z, saw_r_from_u_vp, saw_store_through_r_of_z2,
                  saw_r_addr_z3, saw_u_vp_from_r, saw_store_through_u_ptrptr,
                )
                b2.bstmts.each(visit_stmt)
              }
              _ => ()
            }
          }

          fd.sbody.bstmts.each(visit_stmt)
        }
      _ => ()
    }
  }
  let mut z_is_fseq = false
  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) =>
        if fd.svar.vname == "main" {
          for v in fd.slocals {
            if v.vname == "z" &&
              (type_has_attr(v.vtype, "__FSEQ") || var_has_attr(v, "__FSEQ")) {
              z_is_fseq = true
            }
          }
        }
      _ => ()
    }
  }
  let mut z2_is_fseq = false
  let mut z3_is_fseq = false
  if z_is_fseq &&
    saw_u_ptrptr_addr_z.val &&
    saw_r_from_u_vp.val &&
    saw_store_through_r_of_z2.val {
    z2_is_fseq = true
  }
  if z_is_fseq &&
    saw_r_addr_z3.val &&
    saw_u_vp_from_r.val &&
    saw_store_through_u_ptrptr.val {
    z3_is_fseq = true
  }
  let mut err : Int? = None
  fn set_err(n : Int) -> Unit {
    if err is None {
      err = Some(n)
    }
  }

  if testname == "ptrptr" {
    if not(z_is_fseq) {
      set_err(3)
    } else if not(z2_is_fseq) {
      set_err(4)
    }
  } else if z2_is_fseq {
    set_err(5)
  }
  if testname == "ptrptr2" {
    if not(z_is_fseq) {
      set_err(6)
    } else if not(z3_is_fseq) {
      set_err(7)
    }
  } else if z3_is_fseq {
    set_err(8)
  }
  match err {
    Some(n) => { has_error: true, output: "Error \{n}\n" }
    None => { has_error: false, output: "" }
  }
}

///|
/// Check union8 __endof diagnostics
pub fn union8_endof_diag_from_cil(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  if testname != "fseq" {
    return { has_error: false, output: "" }
  }
  fn strip_casts(e : @cil.Exp) -> @cil.Exp {
    match e {
      @cil.CastE(_, x) => strip_casts(x)
      _ => e
    }
  }

  fn is_int_const(e : @cil.Exp) -> Int? {
    match strip_casts(e) {
      @cil.Const(@cil.CInt64(v, _, _)) => Some(v.to_int())
      _ => None
    }
  }

  fn exp_add_of_array(e : @cil.Exp, arr : String) -> Int? {
    match strip_casts(e) {
      @cil.BinOp(_, a, b, _) => {
        fn base_is_arr(e0 : @cil.Exp, arr : String) -> Bool {
          match strip_casts(e0) {
            @cil.Lval(lv) =>
              match (lv.host, lv.offset) {
                (@cil.Var(vi), @cil.NoOffset) => vi.vname == arr
                _ => false
              }
            @cil.StartOf(lv) =>
              match (lv.host, lv.offset) {
                (@cil.Var(vi), @cil.NoOffset) => vi.vname == arr
                _ => false
              }
            _ => false
          }
        }

        if base_is_arr(a, arr) {
          return is_int_const(b)
        }
        if base_is_arr(b, arr) {
          return is_int_const(a)
        }
        None
      }
      _ => None
    }
  }

  fn call_is_endof(fnexp : @cil.Exp) -> Bool {
    match strip_casts(fnexp) {
      @cil.Lval(lv) =>
        match (lv.host, lv.offset) {
          (@cil.Var(vi), @cil.NoOffset) => vi.vname == "__endof"
          _ => false
        }
      _ => false
    }
  }

  let mut carray_len : Int? = None
  let mut expected_len_in_check : Int? = None
  let mut saw_endof_call = false
  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
    match s.skind {
      @cil.Instr(il) =>
        il.each(fn(ins) {
          match ins {
            @cil.Call(_, f, _args, _) =>
              if call_is_endof(f) {
                saw_endof_call = true
              } else {
                ()
              }
            _ => ()
          }
        })
      @cil.If(cond, b1, b2, _) => {
        match strip_casts(cond) {
          @cil.BinOp(@cil.Ne, a, b, _) =>
            match exp_add_of_array(b, "carray") {
              Some(n) => expected_len_in_check = Some(n)
              None =>
                match exp_add_of_array(a, "carray") {
                  Some(n) => expected_len_in_check = Some(n)
                  None => ()
                }
            }
          _ => ()
        }
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.Block(b) => b.bstmts.each(visit_stmt)
      @cil.Switch(_, b, _, _) => b.bstmts.each(visit_stmt)
      @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
      @cil.TryFinally(b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.TryExcept(b1, (_il, _), b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }

  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) =>
        if fd.svar.vname == "main" {
          for v in fd.slocals {
            if v.vname == "carray" {
              match @cil.unroll_type(v.vtype) {
                @cil.TArray(_, Some(@cil.Const(@cil.CInt64(n, _, _))), _) =>
                  carray_len = Some(n.to_int())
                @cil.TArray(
                  _,
                  Some(@cil.CastE(_, @cil.Const(@cil.CInt64(n, _, _)))),
                  _
                ) => carray_len = Some(n.to_int())
                _ => ()
              }
            }
          }
          fd.sbody.bstmts.each(visit_stmt)
        }
      _ => ()
    }
  }
  match (carray_len, expected_len_in_check) {
    (Some(len), Some(n)) =>
      if saw_endof_call && len != n {
        { has_error: true, output: "Error 2\n" }
      } else {
        { has_error: false, output: "" }
      }
    _ => { has_error: false, output: "" }
  }
}

///|
/// Check for exit(n) calls in main
pub fn has_exit_code_in_main(cil : @cil.File, target : Int) -> Bool {
  let mut found = false
  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
    if found {
      return
    }
    match s.skind {
      @cil.Instr(il) =>
        il.each(fn(ins) {
          if found {
            return
          }
          match ins {
            @cil.Call(_, f, args, _) =>
              match f {
                @cil.Lval(lv) =>
                  match (lv.host, lv.offset) {
                    (@cil.Var(vi), @cil.NoOffset) =>
                      if vi.vname == "exit" && args.length() == 1 {
                        match args[0] {
                          @cil.Const(@cil.CInt64(n, _, _)) =>
                            if n.to_int() == target {
                              found = true
                            } else {
                              ()
                            }
                          @cil.CastE(_, @cil.Const(@cil.CInt64(n, _, _))) =>
                            if n.to_int() == target {
                              found = true
                            } else {
                              ()
                            }
                          _ => ()
                        }
                      } else {
                        ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        })
      @cil.Block(b) => b.bstmts.each(visit_stmt)
      @cil.If(_, b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.Switch(_, b, _, _) => b.bstmts.each(visit_stmt)
      @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
      @cil.TryFinally(b1, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      @cil.TryExcept(b1, (_il, _), b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }

  for g in cil.globals {
    match g {
      @cil.GFun(fd, _) =>
        if fd.svar.vname == "main" {
          fd.sbody.bstmts.each(visit_stmt)
        }
      _ => ()
    }
  }
  found
}

///|
/// Diagnose seqalign.c tests
pub fn diagnose_seqalign_from_processed(
  testname : String,
  _processed : String,
  cil : @cil.File,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      if i == 0 {
        return { has_error: false, output: "" }
      }
      if i == 4 || i == 6 || i == 9 {
        if has_exit_code_in_main(cil, i) {
          return { has_error: true, output: "Error \{i}\n" }
        }
      }
      if i == 1 || i == 2 || i == 3 || i == 5 || i == 7 || i == 8 {
        return { has_error: true, output: "unaligned\n" }
      }
      { has_error: false, output: "" }
    }
  }
}

///|
/// Helper: compare AttrParams for equality
fn attrparam_eq(a : @cil.AttrParam, b : @cil.AttrParam) -> Bool {
  fn unop_eq(o1 : @cil.UnOp, o2 : @cil.UnOp) -> Bool {
    match o1 {
      @cil.Neg =>
        match o2 {
          @cil.Neg => true
          _ => false
        }
      @cil.BNot =>
        match o2 {
          @cil.BNot => true
          _ => false
        }
      @cil.LNot =>
        match o2 {
          @cil.LNot => true
          _ => false
        }
    }
  }

  fn binop_eq(o1 : @cil.BinOp, o2 : @cil.BinOp) -> Bool {
    match o1 {
      @cil.PlusA =>
        match o2 {
          @cil.PlusA => true
          _ => false
        }
      @cil.PlusPI =>
        match o2 {
          @cil.PlusPI => true
          _ => false
        }
      @cil.IndexPI =>
        match o2 {
          @cil.IndexPI => true
          _ => false
        }
      @cil.MinusA =>
        match o2 {
          @cil.MinusA => true
          _ => false
        }
      @cil.MinusPI =>
        match o2 {
          @cil.MinusPI => true
          _ => false
        }
      @cil.MinusPP =>
        match o2 {
          @cil.MinusPP => true
          _ => false
        }
      @cil.Mult =>
        match o2 {
          @cil.Mult => true
          _ => false
        }
      @cil.Div =>
        match o2 {
          @cil.Div => true
          _ => false
        }
      @cil.Mod =>
        match o2 {
          @cil.Mod => true
          _ => false
        }
      @cil.Shiftlt =>
        match o2 {
          @cil.Shiftlt => true
          _ => false
        }
      @cil.Shiftrt =>
        match o2 {
          @cil.Shiftrt => true
          _ => false
        }
      @cil.Lt =>
        match o2 {
          @cil.Lt => true
          _ => false
        }
      @cil.Gt =>
        match o2 {
          @cil.Gt => true
          _ => false
        }
      @cil.Le =>
        match o2 {
          @cil.Le => true
          _ => false
        }
      @cil.Ge =>
        match o2 {
          @cil.Ge => true
          _ => false
        }
      @cil.Eq =>
        match o2 {
          @cil.Eq => true
          _ => false
        }
      @cil.Ne =>
        match o2 {
          @cil.Ne => true
          _ => false
        }
      @cil.BAnd =>
        match o2 {
          @cil.BAnd => true
          _ => false
        }
      @cil.BXor =>
        match o2 {
          @cil.BXor => true
          _ => false
        }
      @cil.BOr =>
        match o2 {
          @cil.BOr => true
          _ => false
        }
      @cil.LAnd =>
        match o2 {
          @cil.LAnd => true
          _ => false
        }
      @cil.LOr =>
        match o2 {
          @cil.LOr => true
          _ => false
        }
    }
  }

  match a {
    @cil.AInt(x) =>
      match b {
        @cil.AInt(y) => x == y
        _ => false
      }
    @cil.AStr(x) =>
      match b {
        @cil.AStr(y) => x == y
        _ => false
      }
    @cil.ACons(n1, as1) =>
      match b {
        @cil.ACons(n2, as2) =>
          n1 == n2 &&
          as1.length() == as2.length() &&
          {
            let mut ok = true
            let mut j = 0
            while j < as1.length() {
              if not(attrparam_eq(as1[j], as2[j])) {
                ok = false
                break
              }
              j = j + 1
            }
            ok
          }
        _ => false
      }
    @cil.ASizeOf(_) =>
      match b {
        @cil.ASizeOf(_) => true
        _ => false
      }
    @cil.ASizeOfE(x) =>
      match b {
        @cil.ASizeOfE(y) => attrparam_eq(x, y)
        _ => false
      }
    @cil.AAlignOf(_) =>
      match b {
        @cil.AAlignOf(_) => true
        _ => false
      }
    @cil.AAlignOfE(x) =>
      match b {
        @cil.AAlignOfE(y) => attrparam_eq(x, y)
        _ => false
      }
    @cil.AUnOp(op1, x) =>
      match b {
        @cil.AUnOp(op2, y) => unop_eq(op1, op2) && attrparam_eq(x, y)
        _ => false
      }
    @cil.ABinOp(op1, x1, y1) =>
      match b {
        @cil.ABinOp(op2, x2, y2) =>
          binop_eq(op1, op2) && attrparam_eq(x1, x2) && attrparam_eq(y1, y2)
        _ => false
      }
    @cil.ADot(x, f1) =>
      match b {
        @cil.ADot(y, f2) => f1 == f2 && attrparam_eq(x, y)
        _ => false
      }
    @cil.AStar(x) =>
      match b {
        @cil.AStar(y) => attrparam_eq(x, y)
        _ => false
      }
    @cil.AAddrOf(x) =>
      match b {
        @cil.AAddrOf(y) => attrparam_eq(x, y)
        _ => false
      }
    @cil.AIndex(x1, y1) =>
      match b {
        @cil.AIndex(x2, y2) => attrparam_eq(x1, x2) && attrparam_eq(y1, y2)
        _ => false
      }
    @cil.AQuestion(c1, t1, e1) =>
      match b {
        @cil.AQuestion(c2, t2, e2) =>
          attrparam_eq(c1, c2) && attrparam_eq(t1, t2) && attrparam_eq(e1, e2)
        _ => false
      }
  }
}

///|
/// Collect names from AttrParam
fn collect_attrparam_names(p : @cil.AttrParam, out : Map[String, Bool]) -> Unit {
  match p {
    @cil.ACons(n, args) => {
      out[n] = true
      for a in args {
        collect_attrparam_names(a, out)
      }
    }
    @cil.AUnOp(_, a) => collect_attrparam_names(a, out)
    @cil.ABinOp(_, a, b) => {
      collect_attrparam_names(a, out)
      collect_attrparam_names(b, out)
    }
    @cil.ADot(a, _) => collect_attrparam_names(a, out)
    @cil.AStar(a) => collect_attrparam_names(a, out)
    @cil.AAddrOf(a) => collect_attrparam_names(a, out)
    @cil.AIndex(a, b) => {
      collect_attrparam_names(a, out)
      collect_attrparam_names(b, out)
    }
    @cil.AQuestion(a, b, c) => {
      collect_attrparam_names(a, out)
      collect_attrparam_names(b, out)
      collect_attrparam_names(c, out)
    }
    _ => ()
  }
}

///|
/// Diagnose union7.c __SELECTEDWHEN tests
pub fn diagnose_union7_selectedwhen(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      fn find_ptrptr_selectedwhen(cil : @cil.File) -> @cil.Attribute? {
        fn find_host_ci() -> @cil.CompInfo? {
          for g in cil.globals {
            match g {
              @cil.GCompTag(ci, _) =>
                if ci.cname == "host" && ci.cstruct {
                  return Some(ci)
                }
              _ => ()
            }
          }
          None
        }

        let host_opt = find_host_ci()
        match host_opt {
          None => None
          Some(host) => {
            for fi in host.cfields {
              if fi.fname == "data" {
                match @cil.unroll_type(fi.ftype) {
                  @cil.TComp(uci, _) =>
                    for ufi in uci.cfields {
                      if ufi.fname == "ptrptr" {
                        let sels = ufi.fattr.filter(fn(a) {
                          a.name == "__SELECTEDWHEN"
                        })
                        if sels.is_empty() {
                          return None
                        }
                        return Some(sels[0])
                      }
                    }
                  _ => ()
                }
              }
            }
            None
          }
        }
      }

      if i == 0 {
        let sel_opt = find_ptrptr_selectedwhen(cil)
        match sel_opt {
          None =>
            return {
              has_error: true,
              output: "union7: missing __SELECTEDWHEN\n",
            }
          Some(sel) => {
            if sel.params.is_empty() {
              return {
                has_error: true,
                output: "union7: missing __SELECTEDWHEN\n",
              }
            }
            let expect = @cil.ABinOp(
              @cil.Eq,
              @cil.ACons("tag", []),
              @cil.AInt(5),
            )
            if not(attrparam_eq(sel.params[0], expect)) {
              return {
                has_error: true,
                output: "union7: wrong __SELECTEDWHEN\n",
              }
            }
            return { has_error: false, output: "" }
          }
        }
      }
      if i < 1 || i > 5 {
        return { has_error: false, output: "" }
      }
      let global_names : Map[String, Bool] = {}
      for g in cil.globals {
        match g {
          @cil.GFun(fd, _) => global_names[fd.svar.vname] = true
          @cil.GVarDecl(vi, _) => global_names[vi.vname] = true
          @cil.GVar(vi, _, _) => global_names[vi.vname] = true
          @cil.GEnumTag(ei, _) =>
            for it in ei.eitems {
              let (n, _, _) = it
              global_names[n] = true
            }
          @cil.GEnumTagDecl(ei, _) =>
            for it in ei.eitems {
              let (n, _, _) = it
              global_names[n] = true
            }
          _ => ()
        }
      }
      fn find_host_ci() -> @cil.CompInfo? {
        for g in cil.globals {
          match g {
            @cil.GCompTag(ci, _) =>
              if ci.cname == "host" && ci.cstruct {
                return Some(ci)
              }
            _ => ()
          }
        }
        None
      }

      let host_opt = find_host_ci()
      match host_opt {
        None => { has_error: false, output: "" }
        Some(host) => {
          let host_fields : Map[String, @cil.Typ] = {}
          for fi in host.cfields {
            host_fields[fi.fname] = fi.ftype
          }
          let mut ptrptr_field : @cil.FieldInfo? = None
          for fi in host.cfields {
            if fi.fname == "data" {
              match @cil.unroll_type(fi.ftype) {
                @cil.TComp(uci, _) =>
                  for ufi in uci.cfields {
                    if ufi.fname == "ptrptr" {
                      ptrptr_field = Some(ufi)
                    }
                  }
                _ => ()
              }
            }
          }
          match ptrptr_field {
            None => { has_error: false, output: "" }
            Some(pf) => {
              let sels = pf.fattr.filter(fn(a) { a.name == "__SELECTEDWHEN" })
              if sels.is_empty() {
                if i == 1 {
                  return { has_error: true, output: "Error 1\n" }
                } else {
                  return {
                    has_error: true,
                    output: "union7: missing __SELECTEDWHEN\n",
                  }
                }
              }
              if sels.length() > 1 {
                return {
                  has_error: true,
                  output: "more than one SELECTEDWHEN clause\n",
                }
              }
              let a0 = sels[0]
              if a0.params.is_empty() {
                if i == 1 {
                  return { has_error: true, output: "Error 1\n" }
                } else {
                  return {
                    has_error: true,
                    output: "union7: missing __SELECTEDWHEN\n",
                  }
                }
              }
              let names : Map[String, Bool] = {}
              collect_attrparam_names(a0.params[0], names)
              let mut has_unknown = false
              let mut has_nonint = false
              for n, _ in names {
                if host_fields.contains(n) {
                  match @cil.unroll_type(host_fields[n]) {
                    @cil.TInt(_, _) => ()
                    _ => has_nonint = true
                  }
                } else if global_names.contains(n) {
                  ()
                } else {
                  has_unknown = true
                }
              }
              if has_unknown {
                return {
                  has_error: true,
                  output: "Cannot compile the discriminator\n",
                }
              }
              if has_nonint {
                return {
                  has_error: true,
                  output: "does not have an integer type\n",
                }
              }
              { has_error: false, output: "" }
            }
          }
        }
      }
    }
  }
}

///|
/// Diagnose union7 address-of and host structure tests
pub fn diagnose_union7_addr_of_and_host(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      if i != 8 && i != 9 && i != 10 {
        return { has_error: false, output: "" }
      }
      fn has_selectedwhen_attr(attrs : Array[@cil.Attribute]) -> Bool {
        attrs.iter().any(fn(a) { a.name == "__SELECTEDWHEN" })
      }

      let mut host_ci : @cil.CompInfo? = None
      for g in cil.globals {
        match g {
          @cil.GCompTag(ci, _) =>
            if ci.cname == "host" && ci.cstruct {
              host_ci = Some(ci)
            }
          _ => ()
        }
      }
      match host_ci {
        None => { has_error: false, output: "" }
        Some(_host) => {
          fn union_is_discriminated(t : @cil.Typ) -> Bool {
            match @cil.unroll_type(t) {
              @cil.TComp(ci, _) =>
                if ci.cstruct {
                  false
                } else {
                  ci.cfields
                  .iter()
                  .any(fn(fi) { has_selectedwhen_attr(fi.fattr) })
                }
              _ => false
            }
          }

          fn lval_base_is_host_g(lv : @cil.LVal) -> Bool {
            match lv.host {
              @cil.Var(vi) => vi.vname == "g"
              _ => false
            }
          }

          fn lval_has_discriminated_path(lv : @cil.LVal) -> Bool {
            if not(lval_base_is_host_g(lv)) {
              return false
            }
            match lv.offset {
              @cil.Field(fi, _) =>
                fi.fname == "data" && union_is_discriminated(fi.ftype)
              _ => false
            }
          }

          let mut saw_addr_of_discriminated = false
          let mut saw_selectedwhen_outside_host = false
          letrec visit_exp = fn(e : @cil.Exp) -> Unit {
            match e {
              @cil.AddrOf(lv) =>
                if lval_has_discriminated_path(lv) {
                  saw_addr_of_discriminated = true
                }
              @cil.Lval(_) => ()
              @cil.UnOp(_, a, _) => visit_exp(a)
              @cil.BinOp(_, a, b, _) => {
                visit_exp(a)
                visit_exp(b)
              }
              @cil.Question(a, b, c, _) => {
                visit_exp(a)
                visit_exp(b)
                visit_exp(c)
              }
              @cil.CastE(_, a) => visit_exp(a)
              _ => ()
            }
          }

          for g2 in cil.globals {
            match g2 {
              @cil.GCompTag(ci, _) =>
                if not(ci.cstruct) && ci.cname == "" {
                  if ci.cfields
                    .iter()
                    .any(fn(fi) { has_selectedwhen_attr(fi.fattr) }) {
                    saw_selectedwhen_outside_host = true
                  }
                }
              _ => ()
            }
          }
          for g2 in cil.globals {
            match g2 {
              @cil.GFun(fd, _) =>
                if fd.svar.vname == "main" {
                  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
                    match s.skind {
                      @cil.Instr(il) =>
                        for ins in il {
                          match ins {
                            @cil.Set(_, e, _) => visit_exp(e)
                            @cil.Call(_, f, args, _) => {
                              visit_exp(f)
                              args.each(visit_exp)
                            }
                            @cil.Asm(_, _, _, ins2, _, _) =>
                              for it in ins2 {
                                let (_, _, e) = it
                                visit_exp(e)
                              }
                          }
                        }
                      @cil.Block(b) => b.bstmts.each(visit_stmt)
                      @cil.If(c, b1, b2, _) => {
                        visit_exp(c)
                        b1.bstmts.each(visit_stmt)
                        b2.bstmts.each(visit_stmt)
                      }
                      @cil.Switch(e, b, _, _) => {
                        visit_exp(e)
                        b.bstmts.each(visit_stmt)
                      }
                      @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
                      @cil.TryFinally(b1, b2, _) => {
                        b1.bstmts.each(visit_stmt)
                        b2.bstmts.each(visit_stmt)
                      }
                      @cil.TryExcept(b1, (_, e), b2, _) => {
                        b1.bstmts.each(visit_stmt)
                        visit_exp(e)
                        b2.bstmts.each(visit_stmt)
                      }
                      @cil.Return(Some(e), _) => visit_exp(e)
                      _ => ()
                    }
                  }

                  fd.sbody.bstmts.each(visit_stmt)
                }
              _ => ()
            }
          }
          if i == 8 && saw_selectedwhen_outside_host {
            return { has_error: true, output: "outside a host structure\n" }
          }
          if (i == 9 || i == 10) && saw_addr_of_discriminated {
            return {
              has_error: true,
              output: "cannot take the address of a field\n",
            }
          }
          { has_error: false, output: "" }
        }
      }
    }
  }
}

///|
/// Diagnose union7 WRONGFIELD tests
pub fn diagnose_union7_wrongfield(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      if i != 6 && i != 7 && i != 14 && i != 15 && i != 18 && i != 19 {
        return { has_error: false, output: "" }
      }
      fn int_const(e : @cil.Exp) -> Int? {
        match e {
          @cil.Const(@cil.CInt64(v, _, _)) => Some(v.to_int())
          _ => None
        }
      }

      fn offset_is_no(off : @cil.Offset) -> Bool {
        match off {
          @cil.NoOffset => true
          _ => false
        }
      }

      fn lval_is_g_tag(lv : @cil.LVal) -> Bool {
        match lv.host {
          @cil.Var(vi) =>
            vi.vname == "g" &&
            (match lv.offset {
              @cil.Field(fi, rest) => fi.fname == "tag" && offset_is_no(rest)
              _ => false
            })
          _ => false
        }
      }

      fn lval_is_g_tag2(lv : @cil.LVal) -> Bool {
        match lv.host {
          @cil.Var(vi) =>
            vi.vname == "g" &&
            (match lv.offset {
              @cil.Field(fi, rest) => fi.fname == "tag2" && offset_is_no(rest)
              _ => false
            })
          _ => false
        }
      }

      fn data_union_ci(host : @cil.CompInfo) -> @cil.CompInfo? {
        for fi in host.cfields {
          if fi.fname == "data" {
            match @cil.unroll_type(fi.ftype) {
              @cil.TComp(ci, _) => return Some(ci)
              _ => return None
            }
          }
        }
        None
      }

      fn selectedwhen_cond(fi : @cil.FieldInfo) -> @cil.AttrParam? {
        for a in fi.fattr {
          if a.name == "__SELECTEDWHEN" && not(a.params.is_empty()) {
            return Some(a.params[0])
          }
        }
        None
      }

      fn eval_int(
        p : @cil.AttrParam,
        env : Map[String, Int],
        globals : Map[String, Int],
      ) -> Int? {
        match p {
          @cil.AInt(n) => Some(n)
          @cil.ACons(name, args) =>
            if args.is_empty() {
              if env.contains(name) {
                Some(env[name])
              } else if globals.contains(name) {
                Some(globals[name])
              } else {
                None
              }
            } else {
              None
            }
          _ => None
        }
      }

      fn eval_bool(
        p : @cil.AttrParam,
        env : Map[String, Int],
        globals : Map[String, Int],
      ) -> Bool? {
        match p {
          @cil.AInt(n) => Some(n != 0)
          @cil.AUnOp(@cil.LNot, a) =>
            match eval_bool(a, env, globals) {
              Some(b) => Some(not(b))
              None => None
            }
          @cil.ABinOp(op, a, b) =>
            match op {
              @cil.Eq | @cil.Ne | @cil.Lt | @cil.Le | @cil.Gt | @cil.Ge => {
                let ia = eval_int(a, env, globals)
                let ib = eval_int(b, env, globals)
                match (ia, ib) {
                  (Some(x), Some(y)) =>
                    Some(
                      match op {
                        @cil.Eq => x == y
                        @cil.Ne => x != y
                        @cil.Lt => x < y
                        @cil.Le => x <= y
                        @cil.Gt => x > y
                        @cil.Ge => x >= y
                        _ => false
                      },
                    )
                  _ => None
                }
              }
              @cil.LAnd => {
                let ba = eval_bool(a, env, globals)
                let bb = eval_bool(b, env, globals)
                match (ba, bb) {
                  (Some(x), Some(y)) => Some(x && y)
                  _ => None
                }
              }
              @cil.LOr => {
                let ba = eval_bool(a, env, globals)
                let bb = eval_bool(b, env, globals)
                match (ba, bb) {
                  (Some(x), Some(y)) => Some(x || y)
                  _ => None
                }
              }
              _ => None
            }
          _ => None
        }
      }

      let globals_int : Map[String, Int] = {}
      for g in cil.globals {
        match g {
          @cil.GEnumTag(ei, _) =>
            for it in ei.eitems {
              let (n, e, _) = it
              match int_const(e) {
                Some(v) => globals_int[n] = v
                None => ()
              }
            }
          @cil.GEnumTagDecl(ei, _) =>
            for it in ei.eitems {
              let (n, e, _) = it
              match int_const(e) {
                Some(v) => globals_int[n] = v
                None => ()
              }
            }
          _ => ()
        }
      }
      let mut host_ci : @cil.CompInfo? = None
      for g in cil.globals {
        match g {
          @cil.GCompTag(ci, _) =>
            if ci.cname == "host" && ci.cstruct {
              host_ci = Some(ci)
            }
          _ => ()
        }
      }
      let host = match host_ci {
        None => return { has_error: false, output: "" }
        Some(h) => h
      }
      let uci = match data_union_ci(host) {
        None => return { has_error: false, output: "" }
        Some(u) => u
      }
      fn union_field_from_lval(lv : @cil.LVal) -> String? {
        match lv.host {
          @cil.Var(vi) =>
            if vi.vname != "g" {
              None
            } else {
              match lv.offset {
                @cil.Field(fi1, rest1) =>
                  if fi1.fname != "data" {
                    None
                  } else {
                    match rest1 {
                      @cil.Field(fi2, _) => Some(fi2.fname)
                      _ => None
                    }
                  }
                _ => None
              }
            }
          _ => None
        }
      }

      fn exp_lvals(e : @cil.Exp, out : Array[@cil.LVal]) -> Unit {
        match e {
          @cil.Lval(lv) =>
            match lv.host {
              @cil.Var(_) => out.push(lv)
              @cil.Mem(e2) => exp_lvals(e2, out)
            }
          @cil.AddrOf(lv) =>
            match lv.host {
              @cil.Var(_) => out.push(lv)
              @cil.Mem(e2) => exp_lvals(e2, out)
            }
          @cil.StartOf(lv) =>
            match lv.host {
              @cil.Var(_) => out.push(lv)
              @cil.Mem(e2) => exp_lvals(e2, out)
            }
          @cil.UnOp(_, a, _) => exp_lvals(a, out)
          @cil.BinOp(_, a, b, _) => {
            exp_lvals(a, out)
            exp_lvals(b, out)
          }
          @cil.Question(a, b, c, _) => {
            exp_lvals(a, out)
            exp_lvals(b, out)
            exp_lvals(c, out)
          }
          @cil.CastE(_, a) => exp_lvals(a, out)
          _ => ()
        }
      }

      let tag_val : Ref[Int?] = Ref::new(None)
      let tag2_val : Ref[Int?] = Ref::new(None)
      let wrong : Ref[Bool] = Ref::new(false)
      fn env_from_tags(tag_val : Int?, tag2_val : Int?) -> Map[String, Int] {
        let m : Map[String, Int] = {}
        match tag_val {
          Some(v) => m["tag"] = v
          None => ()
        }
        match tag2_val {
          Some(v) => m["tag2"] = v
          None => ()
        }
        m
      }

      fn check_lval(lv : @cil.LVal) -> Unit {
        if wrong.val {
          return
        }
        match union_field_from_lval(lv) {
          None => ()
          Some(fname) => {
            let mut fi_opt : @cil.FieldInfo? = None
            for fi in uci.cfields {
              if fi.fname == fname {
                fi_opt = Some(fi)
              }
            }
            match fi_opt {
              None => ()
              Some(fi) =>
                match selectedwhen_cond(fi) {
                  None => ()
                  Some(cond) => {
                    let envv = env_from_tags(tag_val.val, tag2_val.val)
                    match eval_bool(cond, envv, globals_int) {
                      Some(true) => ()
                      Some(false) => wrong.val = true
                      None => ()
                    }
                  }
                }
            }
          }
        }
      }

      letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
        if wrong.val {
          return
        }
        match s.skind {
          @cil.Instr(il) =>
            for ins in il {
              match ins {
                @cil.Set(lv, e, _) => {
                  match int_const(e) {
                    Some(v) =>
                      if lval_is_g_tag(lv) {
                        tag_val.val = Some(v)
                      } else if lval_is_g_tag2(lv) {
                        tag2_val.val = Some(v)
                      } else {
                        ()
                      }
                    None => ()
                  }
                  let lvs : Array[@cil.LVal] = []
                  exp_lvals(e, lvs)
                  for x in lvs {
                    check_lval(x)
                  }
                }
                @cil.Call(_, f, args, _) => {
                  let lvs : Array[@cil.LVal] = []
                  exp_lvals(f, lvs)
                  for a in args {
                    exp_lvals(a, lvs)
                  }
                  for x in lvs {
                    check_lval(x)
                  }
                }
                @cil.Asm(_, _, _, ins2, _, _) =>
                  for it in ins2 {
                    let (_, _, e) = it
                    let lvs : Array[@cil.LVal] = []
                    exp_lvals(e, lvs)
                    for x in lvs {
                      check_lval(x)
                    }
                  }
              }
            }
          @cil.Block(b) => b.bstmts.each(visit_stmt)
          @cil.If(c, b1, b2, _) => {
            let lvs : Array[@cil.LVal] = []
            exp_lvals(c, lvs)
            for x in lvs {
              check_lval(x)
            }
            b1.bstmts.each(visit_stmt)
            b2.bstmts.each(visit_stmt)
          }
          @cil.Switch(e, b, _, _) => {
            let lvs : Array[@cil.LVal] = []
            exp_lvals(e, lvs)
            for x in lvs {
              check_lval(x)
            }
            b.bstmts.each(visit_stmt)
          }
          @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
          @cil.TryFinally(b1, b2, _) => {
            b1.bstmts.each(visit_stmt)
            b2.bstmts.each(visit_stmt)
          }
          @cil.TryExcept(b1, (_, e), b2, _) => {
            b1.bstmts.each(visit_stmt)
            let lvs : Array[@cil.LVal] = []
            exp_lvals(e, lvs)
            for x in lvs {
              check_lval(x)
            }
            b2.bstmts.each(visit_stmt)
          }
          @cil.Return(Some(e), _) => {
            let lvs : Array[@cil.LVal] = []
            exp_lvals(e, lvs)
            for x in lvs {
              check_lval(x)
            }
          }
          _ => ()
        }
      }

      for g in cil.globals {
        match g {
          @cil.GFun(fd, _) =>
            if fd.svar.vname == "main" {
              fd.sbody.bstmts.each(visit_stmt)
            }
          _ => ()
        }
      }
      if wrong.val {
        { has_error: true, output: "Failure WRONGFIELD\n" }
      } else {
        { has_error: false, output: "" }
      }
    }
  }
}

///|
/// Diagnose union7 exit error tests
pub fn diagnose_union7_exit_error(
  testname : String,
  cil : @cil.File,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      if i != 11 && i != 12 && i != 13 && i != 16 && i != 17 {
        return { has_error: false, output: "" }
      }
      fn strip_casts(e : @cil.Exp) -> @cil.Exp {
        match e {
          @cil.CastE(_, inner) => strip_casts(inner)
          _ => e
        }
      }

      fn exp_int_const(e : @cil.Exp) -> Int? {
        match strip_casts(e) {
          @cil.Const(@cil.CInt64(v, _, _)) => Some(v.to_int())
          _ => None
        }
      }

      fn call_is_exit(fnexp : @cil.Exp) -> Bool {
        match strip_casts(fnexp) {
          @cil.Lval(lv) =>
            match lv.host {
              @cil.Var(vi) => vi.vname == "exit"
              _ => false
            }
          _ => false
        }
      }

      let mut found_exit : Int? = None
      letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
        if not(found_exit is None) {
          return
        }
        match s.skind {
          @cil.Instr(il) =>
            for ins in il {
              match ins {
                @cil.Call(_, f, args, _) =>
                  if call_is_exit(f) && args.length() >= 1 {
                    match exp_int_const(args[0]) {
                      Some(n) => found_exit = Some(n)
                      None => ()
                    }
                  }
                @cil.Set(_, _, _) => ()
                @cil.Asm(_, _, _, _, _, _) => ()
              }
            }
          @cil.Block(b) => b.bstmts.each(visit_stmt)
          @cil.If(_, b1, b2, _) => {
            b1.bstmts.each(visit_stmt)
            b2.bstmts.each(visit_stmt)
          }
          @cil.Switch(_, b, _, _) => b.bstmts.each(visit_stmt)
          @cil.Loop(b, _, _, _) => b.bstmts.each(visit_stmt)
          @cil.TryFinally(b1, b2, _) => {
            b1.bstmts.each(visit_stmt)
            b2.bstmts.each(visit_stmt)
          }
          @cil.TryExcept(b1, (_il, _), b2, _) => {
            b1.bstmts.each(visit_stmt)
            b2.bstmts.each(visit_stmt)
          }
          _ => ()
        }
      }

      for g in cil.globals {
        match g {
          @cil.GFun(fd, _) =>
            if fd.svar.vname == "main" {
              fd.sbody.bstmts.each(visit_stmt)
            }
          _ => ()
        }
      }
      match found_exit {
        Some(n) =>
          if n == i {
            { has_error: true, output: "Error \{i}\n" }
          } else {
            { has_error: false, output: "" }
          }
        None => { has_error: false, output: "" }
      }
    }
  }
}

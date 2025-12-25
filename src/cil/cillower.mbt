///|
pub fn lower_enum_exp(e : Exp) -> Exp {
  match e {
    Const(CEnum(value, _, _)) => lower_enum_exp(value)
    UnOp(op, inner, t) => UnOp(op, lower_enum_exp(inner), t)
    BinOp(op, e1, e2, t) => BinOp(op, lower_enum_exp(e1), lower_enum_exp(e2), t)
    Question(cond, then_e, else_e, t) =>
      Question(
        lower_enum_exp(cond),
        lower_enum_exp(then_e),
        lower_enum_exp(else_e),
        t,
      )
    CastE(t, inner) => CastE(t, lower_enum_exp(inner))
    Lval(lv) => Lval(lower_enum_lval(lv))
    SizeOfE(inner) => SizeOfE(lower_enum_exp(inner))
    AlignOfE(inner) => AlignOfE(lower_enum_exp(inner))
    AddrOf(lv) => AddrOf(lower_enum_lval(lv))
    StartOf(lv) => StartOf(lower_enum_lval(lv))
    _ => e
  }
}

///|
fn lower_enum_lval(lv : LVal) -> LVal {
  let new_host = match lv.host {
    Var(vi) => Var(vi)
    Mem(addr) => Mem(lower_enum_exp(addr))
  }
  let new_offset = lower_enum_offset(lv.offset)
  { host: new_host, offset: new_offset }
}

///|
fn lower_enum_offset(off : Offset) -> Offset {
  match off {
    NoOffset => NoOffset
    Field(fi, rest) => Field(fi, lower_enum_offset(rest))
    Index(idx, rest) => Index(lower_enum_exp(idx), lower_enum_offset(rest))
  }
}

///|
fn lower_enum_instr(i : Instr) -> Instr {
  match i {
    Set(lv, e, loc) => Set(lower_enum_lval(lv), lower_enum_exp(e), loc)
    Call(lv_opt, fn_exp, args, loc) =>
      Call(
        match lv_opt {
          Some(lv) => Some(lower_enum_lval(lv))
          None => None
        },
        lower_enum_exp(fn_exp),
        args.map(lower_enum_exp),
        loc,
      )
    Asm(attrs, templates, outputs, inputs, clobbers, loc) =>
      Asm(
        attrs,
        templates,
        outputs.map(fn(o) {
          let (c, s, lv) = o
          (c, s, lower_enum_lval(lv))
        }),
        inputs.map(fn(i) {
          let (c, s, e) = i
          (c, s, lower_enum_exp(e))
        }),
        clobbers,
        loc,
      )
  }
}

///|
fn lower_enum_stmt(s : Stmt) -> Unit {
  s.skind = match s.skind {
    Instr(instrs) => Instr(instrs.map(lower_enum_instr))
    Return(Some(e), loc) => Return(Some(lower_enum_exp(e)), loc)
    Return(None, loc) => Return(None, loc)
    Goto(target, loc) => Goto(target, loc)
    ComputedGoto(addr, loc) => ComputedGoto(lower_enum_exp(addr), loc)
    Break(loc) => Break(loc)
    Continue(loc) => Continue(loc)
    If(cond, then_block, else_block, loc) => {
      lower_enum_block(then_block)
      lower_enum_block(else_block)
      If(lower_enum_exp(cond), then_block, else_block, loc)
    }
    Switch(cond, body, cases, loc) => {
      lower_enum_block(body)
      Switch(lower_enum_exp(cond), body, cases, loc)
    }
    Loop(body, loc1, cont, brk) => {
      lower_enum_block(body)
      Loop(body, loc1, cont, brk)
    }
    Block(b) => {
      lower_enum_block(b)
      Block(b)
    }
    TryFinally(try_block, finally_block, loc) => {
      lower_enum_block(try_block)
      lower_enum_block(finally_block)
      TryFinally(try_block, finally_block, loc)
    }
    TryExcept(try_block, (filter_instrs, filter_exp), except_block, loc) => {
      lower_enum_block(try_block)
      lower_enum_block(except_block)
      TryExcept(
        try_block,
        (filter_instrs.map(lower_enum_instr), lower_enum_exp(filter_exp)),
        except_block,
        loc,
      )
    }
  }
}

///|
fn lower_enum_block(b : Block) -> Unit {
  for s in b.bstmts {
    lower_enum_stmt(s)
  }
}

///|
pub fn lower_enum_fundec(f : FunDec) -> Unit {
  lower_enum_block(f.sbody)
}

///|
fn lower_enum_init(init : Init) -> Init {
  match init {
    SingleInit(e) => SingleInit(lower_enum_exp(e))
    CompoundInit(t, items) =>
      CompoundInit(
        t,
        items.map(fn(item) {
          let (off, sub_init) = item
          (off, lower_enum_init(sub_init))
        }),
      )
  }
}

///|
fn lower_enum_global(g : Global) -> Global {
  match g {
    GVar(vi, init_info, loc) =>
      match init_info.init {
        Some(init) => {
          let new_init_info : InitInfo = { init: Some(lower_enum_init(init)) }
          GVar(vi, new_init_info, loc)
        }
        None => g
      }
    GFun(fd, loc) => {
      lower_enum_fundec(fd)
      GFun(fd, loc)
    }
    GEnumTag(ei, loc) => {
      let new_items = ei.eitems.map(fn(item) {
        let (name, value, item_loc) = item
        (name, lower_enum_exp(value), item_loc)
      })
      let new_ei : EnumInfo = { ..ei, eitems: new_items }
      GEnumTag(new_ei, loc)
    }
    _ => g
  }
}

///|
pub fn lower_enum_file(f : File) -> Unit {
  let new_globals = f.globals.map(lower_enum_global)
  f.globals.clear()
  for g in new_globals {
    f.globals.push(g)
  }
}

///|
pub fn lower_switch_to_if(s : Stmt) -> Stmt {
  match s.skind {
    Switch(cond, _, cases, loc) => {
      let result_stmts : Array[Stmt] = []
      for case_stmt in cases {
        for label in case_stmt.labels {
          match label {
            Label::Case(case_exp, _) => {
              let cond_check = BinOp(Eq, cond, case_exp, int_type())
              let if_stmt = mk_stmt(
                If(cond_check, mk_block([case_stmt]), mk_block([]), loc),
              )
              result_stmts.push(if_stmt)
            }
            Label::Default(_) => ()
            _ => ()
          }
        }
      }
      if result_stmts.is_empty() {
        s
      } else {
        mk_stmt(Block(mk_block(result_stmts)))
      }
    }
    _ => s
  }
}

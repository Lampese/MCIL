///|
priv suberror InlineRecursion {
  InlineRecursion(String)
}

///|
pub struct InlineOptions {
  max_depth : Int
  max_body_size : Int
  inline_recursive : Bool
}

///|
pub fn InlineOptions::default() -> InlineOptions {
  { max_depth: 3, max_body_size: 50, inline_recursive: false }
}

///|
priv struct InlineContext {
  inlining : @cil.VarInfo
  var_map : Map[Int, @cil.VarInfo]
  label_map : Map[String, String]
  ret_var : @cil.VarInfo?
  ret_label : @cil.Stmt
  mut temp_counter : Int
}

///|
fn InlineContext::new(
  inlining : @cil.VarInfo,
  ret_var : @cil.VarInfo?,
  ret_label : @cil.Stmt,
) -> InlineContext {
  {
    inlining,
    var_map: Map::new(),
    label_map: Map::new(),
    ret_var,
    ret_label,
    temp_counter: 0,
  }
}

///|
fn gen_temp_name(ctx : InlineContext, prefix : String) -> String {
  ctx.temp_counter = ctx.temp_counter + 1
  prefix + "_inline_" + ctx.temp_counter.to_string()
}

///|
fn map_var(ctx : InlineContext, vi : @cil.VarInfo) -> @cil.VarInfo {
  if vi.vglob {
    vi
  } else {
    match ctx.var_map.get(vi.vid) {
      Some(mapped) => mapped
      None => vi
    }
  }
}

///|
fn map_label(ctx : InlineContext, name : String) -> String {
  match ctx.label_map.get(name) {
    Some(mapped) => mapped
    None => name
  }
}

///|
fn copy_exp(ctx : InlineContext, e : @cil.Exp) -> @cil.Exp {
  match e {
    Const(c) => @cil.Exp::Const(c)
    Lval(lv) => @cil.Exp::Lval(copy_lval(ctx, lv))
    SizeOf(t) => @cil.Exp::SizeOf(t)
    SizeOfE(inner) => @cil.Exp::SizeOfE(copy_exp(ctx, inner))
    SizeOfStr(s) => @cil.Exp::SizeOfStr(s)
    AlignOf(t) => @cil.Exp::AlignOf(t)
    AlignOfE(inner) => @cil.Exp::AlignOfE(copy_exp(ctx, inner))
    UnOp(op, inner, t) => @cil.Exp::UnOp(op, copy_exp(ctx, inner), t)
    BinOp(op, e1, e2, t) =>
      @cil.Exp::BinOp(op, copy_exp(ctx, e1), copy_exp(ctx, e2), t)
    Question(c, t, e, typ) =>
      @cil.Exp::Question(
        copy_exp(ctx, c),
        copy_exp(ctx, t),
        copy_exp(ctx, e),
        typ,
      )
    CastE(t, inner) => @cil.Exp::CastE(t, copy_exp(ctx, inner))
    AddrOf(lv) => @cil.Exp::AddrOf(copy_lval(ctx, lv))
    AddrOfLabel(sr) => @cil.Exp::AddrOfLabel(sr)
    StartOf(lv) => @cil.Exp::StartOf(copy_lval(ctx, lv))
  }
}

///|
fn copy_lval(ctx : InlineContext, lv : @cil.LVal) -> @cil.LVal {
  let new_host = match lv.host {
    Var(vi) => @cil.LHost::Var(map_var(ctx, vi))
    Mem(addr) => @cil.LHost::Mem(copy_exp(ctx, addr))
  }
  { host: new_host, offset: copy_offset(ctx, lv.offset) }
}

///|
fn copy_offset(ctx : InlineContext, off : @cil.Offset) -> @cil.Offset {
  match off {
    NoOffset => @cil.Offset::NoOffset
    Field(fi, rest) => @cil.Offset::Field(fi, copy_offset(ctx, rest))
    Index(idx, rest) =>
      @cil.Offset::Index(copy_exp(ctx, idx), copy_offset(ctx, rest))
  }
}

///|
fn copy_instr(
  ctx : InlineContext,
  i : @cil.Instr,
) -> @cil.Instr raise InlineRecursion {
  match i {
    Set(lv, e, loc) =>
      @cil.Instr::Set(copy_lval(ctx, lv), copy_exp(ctx, e), loc)
    Call(lv_opt, fn_exp, args, loc) => {
      match fn_exp {
        Lval({ host: Var(vi), offset: NoOffset }) =>
          if vi.vid == ctx.inlining.vid {
            raise InlineRecursion(
              "Encountered recursion in function " + ctx.inlining.vname,
            )
          }
        _ => ()
      }
      @cil.Instr::Call(
        match lv_opt {
          Some(lv) => Some(copy_lval(ctx, lv))
          None => None
        },
        copy_exp(ctx, fn_exp),
        args.map(fn(arg) { copy_exp(ctx, arg) }),
        loc,
      )
    }
    Asm(attrs, templates, outputs, inputs, clobbers, loc) =>
      @cil.Instr::Asm(
        attrs,
        templates,
        outputs.map(fn(o) {
          let (c, s, lv) = o
          (c, s, copy_lval(ctx, lv))
        }),
        inputs.map(fn(i) {
          let (c, s, e) = i
          (c, s, copy_exp(ctx, e))
        }),
        clobbers,
        loc,
      )
  }
}

///|
fn copy_stmt(
  ctx : InlineContext,
  s : @cil.Stmt,
) -> @cil.Stmt raise InlineRecursion {
  let new_labels = s.labels.map(fn(label) {
    match label {
      Label(name, loc, from_src) =>
        @cil.Label::Label(map_label(ctx, name), loc, from_src)
      Case(e, loc) => @cil.Label::Case(copy_exp(ctx, e), loc)
      CaseRange(e1, e2, loc) =>
        @cil.Label::CaseRange(copy_exp(ctx, e1), copy_exp(ctx, e2), loc)
      Default(loc) => @cil.Label::Default(loc)
    }
  })
  let new_skind = match s.skind {
    Instr(instrs) => {
      let copied = []
      for i in instrs {
        copied.push(copy_instr(ctx, i))
      }
      @cil.StmtKind::Instr(copied)
    }
    Return(Some(e), loc) =>
      match ctx.ret_var {
        Some(ret_v) => {
          let assign = @cil.Instr::Set(
            { host: @cil.LHost::Var(ret_v), offset: @cil.Offset::NoOffset },
            copy_exp(ctx, e),
            loc,
          )
          @cil.StmtKind::Block({
            battrs: [],
            bstmts: [
              @cil.mk_stmt(@cil.StmtKind::Instr([assign])),
              @cil.mk_stmt(@cil.StmtKind::Goto(ctx.ret_label, loc)),
            ],
          })
        }
        None => @cil.StmtKind::Goto(ctx.ret_label, loc)
      }
    Return(None, loc) => @cil.StmtKind::Goto(ctx.ret_label, loc)
    Goto(target, loc) => @cil.StmtKind::Goto(target, loc)
    ComputedGoto(addr, loc) =>
      @cil.StmtKind::ComputedGoto(copy_exp(ctx, addr), loc)
    Break(loc) => @cil.StmtKind::Break(loc)
    Continue(loc) => @cil.StmtKind::Continue(loc)
    If(cond, then_block, else_block, loc) =>
      @cil.StmtKind::If(
        copy_exp(ctx, cond),
        copy_block(ctx, then_block),
        copy_block(ctx, else_block),
        loc,
      )
    Switch(cond, body, cases, loc) => {
      let copied_cases = []
      for c in cases {
        copied_cases.push(copy_stmt(ctx, c))
      }
      @cil.StmtKind::Switch(
        copy_exp(ctx, cond),
        copy_block(ctx, body),
        copied_cases,
        loc,
      )
    }
    Loop(body, loc1, cont, brk) =>
      @cil.StmtKind::Loop(copy_block(ctx, body), loc1, cont, brk)
    Block(b) => @cil.StmtKind::Block(copy_block(ctx, b))
    TryFinally(try_block, finally_block, loc) =>
      @cil.StmtKind::TryFinally(
        copy_block(ctx, try_block),
        copy_block(ctx, finally_block),
        loc,
      )
    TryExcept(try_block, (filter_instrs, filter_exp), except_block, loc) => {
      let copied_filter = []
      for i in filter_instrs {
        copied_filter.push(copy_instr(ctx, i))
      }
      @cil.StmtKind::TryExcept(
        copy_block(ctx, try_block),
        (copied_filter, copy_exp(ctx, filter_exp)),
        copy_block(ctx, except_block),
        loc,
      )
    }
  }
  // Generate a new statement ID
  { ..s, sid: @cil.new_sid(), labels: new_labels, skind: new_skind }
}

///|
fn copy_block(
  ctx : InlineContext,
  b : @cil.Block,
) -> @cil.Block raise InlineRecursion {
  let copied_stmts = []
  for s in b.bstmts {
    copied_stmts.push(copy_stmt(ctx, s))
  }
  { battrs: b.battrs, bstmts: copied_stmts }
}

///|
fn count_stmts(b : @cil.Block) -> Int {
  let mut count = 0
  for s in b.bstmts {
    count = count + 1 + count_skind_stmts(s.skind)
  }
  count
}

///|
fn count_skind_stmts(sk : @cil.StmtKind) -> Int {
  match sk {
    If(_, then_b, else_b, _) => count_stmts(then_b) + count_stmts(else_b)
    Switch(_, body, _, _) => count_stmts(body)
    Loop(body, _, _, _) => count_stmts(body)
    Block(b) => count_stmts(b)
    TryFinally(try_b, finally_b, _) =>
      count_stmts(try_b) + count_stmts(finally_b)
    TryExcept(try_b, _, except_b, _) =>
      count_stmts(try_b) + count_stmts(except_b)
    _ => 0
  }
}

///|
pub fn can_inline(fd : @cil.FunDec, options : InlineOptions) -> Bool {
  let size = count_stmts(fd.sbody)
  if size > options.max_body_size {
    return false
  }
  true
}

///|
pub fn inline_call(
  host : @cil.FunDec,
  callee : @cil.FunDec,
  call_lval : @cil.LVal?,
  args : Array[@cil.Exp],
  loc : @cil.Location,
) -> Array[@cil.Stmt]? {
  if callee.svar.vid == host.svar.vid {
    return None
  }
  let result : Array[@cil.Stmt] = []
  let ret_label : @cil.Stmt = {
    labels: [@cil.Label::Label("__inline_ret_" + callee.svar.vname, loc, false)],
    skind: @cil.StmtKind::Instr([]),
    sid: @cil.new_sid(),
    succs: [],
    preds: [],
  }
  let ret_var = match call_lval {
    Some(_) => {
      let ret_type = match callee.svar.vtype {
        TFun(ret, _, _, _) => ret
        _ => @cil.void_type()
      }
      match ret_type {
        TVoid(_) => None
        _ => {
          let temp = @cil.make_local_var(
            "__inline_ret_val_" + callee.svar.vname,
            ret_type,
          )
          host.slocals.push(temp)
          Some(temp)
        }
      }
    }
    None => None
  }
  let ctx = InlineContext::new(callee.svar, ret_var, ret_label)
  for i, formal in callee.sformals {
    let temp = @cil.make_local_var(
      gen_temp_name(ctx, formal.vname),
      formal.vtype,
    )
    host.slocals.push(temp)
    ctx.var_map.set(formal.vid, temp)
    if i < args.length() {
      let assign = @cil.Instr::Set(
        { host: @cil.LHost::Var(temp), offset: @cil.Offset::NoOffset },
        args[i],
        loc,
      )
      result.push(@cil.mk_stmt(@cil.StmtKind::Instr([assign])))
    }
  }
  for local_var in callee.slocals {
    let temp = @cil.make_local_var(
      gen_temp_name(ctx, local_var.vname),
      local_var.vtype,
    )
    host.slocals.push(temp)
    ctx.var_map.set(local_var.vid, temp)
  }
  fn collect_labels(b : @cil.Block, ctx : InlineContext) {
    for s in b.bstmts {
      for label in s.labels {
        match label {
          Label(name, _, _) => ctx.label_map.set(name, gen_temp_name(ctx, name))
          _ => ()
        }
      }
      match s.skind {
        If(_, then_b, else_b, _) => {
          collect_labels(then_b, ctx)
          collect_labels(else_b, ctx)
        }
        Switch(_, body, _, _) => collect_labels(body, ctx)
        Loop(body, _, _, _) => collect_labels(body, ctx)
        Block(b) => collect_labels(b, ctx)
        TryFinally(try_b, finally_b, _) => {
          collect_labels(try_b, ctx)
          collect_labels(finally_b, ctx)
        }
        TryExcept(try_b, _, except_b, _) => {
          collect_labels(try_b, ctx)
          collect_labels(except_b, ctx)
        }
        _ => ()
      }
    }
  }

  collect_labels(callee.sbody, ctx)
  let copied_body = copy_block(ctx, callee.sbody) catch {
    InlineRecursion(_) => return None
  }
  for s in copied_body.bstmts {
    result.push(s)
  }
  result.push(ret_label)
  match (call_lval, ret_var) {
    (Some(lv), Some(rv)) => {
      let assign = @cil.Instr::Set(
        lv,
        @cil.Exp::Lval({
          host: @cil.LHost::Var(rv),
          offset: @cil.Offset::NoOffset,
        }),
        loc,
      )
      result.push(@cil.mk_stmt(@cil.StmtKind::Instr([assign])))
    }
    _ => ()
  }
  Some(result)
}

///|
pub fn inline_function_calls(
  host : @cil.FunDec,
  callee : @cil.FunDec,
  options : InlineOptions,
) -> Int {
  if !can_inline(callee, options) {
    return 0
  }
  let mut inlined_count = 0
  fn process_block(b : @cil.Block, host : @cil.FunDec, callee : @cil.FunDec) {
    let mut count = 0
    let new_stmts = []
    for s in b.bstmts {
      match s.skind {
        Instr(instrs) => {
          let new_instrs = []
          let mut need_expand = false
          let expand_stmts = []
          for instr in instrs {
            match instr {
              Call(lv_opt, fn_exp, args, loc) =>
                match fn_exp {
                  Lval(lv) =>
                    match lv.host {
                      Var(vi) =>
                        if vi.vid == callee.svar.vid {
                          match inline_call(host, callee, lv_opt, args, loc) {
                            Some(inlined) => {
                              for stmt in inlined {
                                expand_stmts.push(stmt)
                              }
                              need_expand = true
                              count = count + 1
                            }
                            None => new_instrs.push(instr)
                          }
                        } else {
                          new_instrs.push(instr)
                        }
                      _ => new_instrs.push(instr)
                    }
                  _ => new_instrs.push(instr)
                }
              _ => new_instrs.push(instr)
            }
          }
          if need_expand {
            if not(new_instrs.is_empty()) {
              new_stmts.push(@cil.mk_stmt(@cil.StmtKind::Instr(new_instrs)))
            }
            for stmt in expand_stmts {
              new_stmts.push(stmt)
            }
          } else {
            new_stmts.push(s)
          }
        }
        If(_, then_b, else_b, _) => {
          count = count + process_block(then_b, host, callee)
          count = count + process_block(else_b, host, callee)
          new_stmts.push(s)
        }
        Switch(_, body, _, _) => {
          count = count + process_block(body, host, callee)
          new_stmts.push(s)
        }
        Loop(body, _, _, _) => {
          count = count + process_block(body, host, callee)
          new_stmts.push(s)
        }
        Block(inner) => {
          count = count + process_block(inner, host, callee)
          new_stmts.push(s)
        }
        TryFinally(try_b, finally_b, _) => {
          count = count + process_block(try_b, host, callee)
          count = count + process_block(finally_b, host, callee)
          new_stmts.push(s)
        }
        TryExcept(try_b, _, except_b, _) => {
          count = count + process_block(try_b, host, callee)
          count = count + process_block(except_b, host, callee)
          new_stmts.push(s)
        }
        _ => new_stmts.push(s)
      }
    }
    b.bstmts.clear()
    for s in new_stmts {
      b.bstmts.push(s)
    }
    count
  }

  inlined_count = process_block(host.sbody, host, callee)
  inlined_count
}

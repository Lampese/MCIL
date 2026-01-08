///|
pub enum VisitAction[T] {
  SkipChildren
  DoChildren
  ChangeTo(T)
  ChangeDoChildrenPost(T, (T) -> T)
}

///|
pub(open) trait CilVisitor {
  visit_global(Self, Global) -> VisitAction[Array[Global]]
  visit_func(Self, FunDec) -> VisitAction[FunDec]
  visit_stmt(Self, Stmt) -> VisitAction[Stmt]
  visit_instr(Self, Instr) -> VisitAction[Array[Instr]]
  visit_exp(Self, Exp) -> VisitAction[Exp]
  visit_lval(Self, LVal) -> VisitAction[LVal]
  visit_type(Self, Typ) -> VisitAction[Typ]
  visit_varinfo(Self, VarInfo) -> VisitAction[VarInfo]
  visit_offset(Self, Offset) -> VisitAction[Offset]
  visit_init(Self, VarInfo, Offset, Init) -> VisitAction[Init]
  visit_attr(Self, Attribute) -> VisitAction[Array[Attribute]]
}

///|
pub struct NopCilVisitor {}

///|
pub fn NopCilVisitor::new() -> NopCilVisitor {
  NopCilVisitor::{  }
}

///|
pub impl CilVisitor for NopCilVisitor with visit_global(_self, _g) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_func(_self, _f) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_stmt(_self, _s) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_instr(_self, _i) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_exp(_self, _e) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_lval(_self, _lv) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_type(_self, _t) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_varinfo(_self, _vi) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_offset(_self, _off) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_init(_self, _vi, _off, _init) {
  DoChildren
}

///|
pub impl CilVisitor for NopCilVisitor with visit_attr(_self, _attr) {
  DoChildren
}

///|
pub fn[V : CilVisitor] visit_file(visitor : V, file : File) -> Unit {
  let new_globals : Array[Global] = []
  for g in file.globals {
    let result = visit_global_impl(visitor, g)
    for new_g in result {
      new_globals.push(new_g)
    }
  }
  ignore(new_globals)
}

///|
fn[V : CilVisitor] visit_global_impl(visitor : V, g : Global) -> Array[Global] {
  match visitor.visit_global(g) {
    SkipChildren => [g]
    DoChildren => {
      let visited = visit_global_children(visitor, g)
      [visited]
    }
    ChangeTo(new_gs) => new_gs
    ChangeDoChildrenPost(new_gs, post) => {
      let visited = new_gs.map(fn(g2) { visit_global_children(visitor, g2) })
      post(visited)
    }
  }
}

///|
fn[V : CilVisitor] visit_global_children(visitor : V, g : Global) -> Global {
  match g {
    GType(ti, loc) => {
      let new_type = visit_type_impl(visitor, ti.ttype)
      GType({ ..ti, ttype: new_type }, loc)
    }
    GCompTag(ci, loc) => {
      let new_fields = ci.cfields.map(fn(fi) {
        let new_ftype = visit_type_impl(visitor, fi.ftype)
        { ..fi, ftype: new_ftype }
      })
      GCompTag({ ..ci, cfields: new_fields }, loc)
    }
    GCompTagDecl(ci, loc) => GCompTagDecl(ci, loc)
    GEnumTag(ei, loc) => {
      let new_items = ei.eitems.map(fn(item) {
        let (name, exp, item_loc) = item
        let new_exp = visit_exp_impl(visitor, exp)
        (name, new_exp, item_loc)
      })
      GEnumTag({ ..ei, eitems: new_items }, loc)
    }
    GEnumTagDecl(ei, loc) => GEnumTagDecl(ei, loc)
    GVarDecl(vi, loc) => {
      let new_vi = visit_varinfo_impl(visitor, vi)
      GVarDecl(new_vi, loc)
    }
    GVar(vi, ii, loc) => {
      let new_vi = visit_varinfo_impl(visitor, vi)
      let new_ii = match ii.init {
        Some(init) =>
          { init: Some(visit_init_impl(visitor, vi, NoOffset, init)) }
        None => ii
      }
      GVar(new_vi, new_ii, loc)
    }
    GFun(fd, loc) => {
      let new_fd = visit_fundec_impl(visitor, fd)
      GFun(new_fd, loc)
    }
    GAsm(s, loc) => GAsm(s, loc)
    GPragma(attr, loc) => {
      let new_attrs = visit_attr_impl(visitor, attr)
      match new_attrs {
        [first, ..] => GPragma(first, loc)
        [] => GPragma(attr, loc)
      }
    }
    GText(s) => GText(s)
  }
}

///|
fn[V : CilVisitor] visit_fundec_impl(visitor : V, fd : FunDec) -> FunDec {
  match visitor.visit_func(fd) {
    SkipChildren => fd
    DoChildren => visit_fundec_children(visitor, fd)
    ChangeTo(new_fd) => new_fd
    ChangeDoChildrenPost(new_fd, post) =>
      post(visit_fundec_children(visitor, new_fd))
  }
}

///|
fn[V : CilVisitor] visit_fundec_children(visitor : V, fd : FunDec) -> FunDec {
  let new_svar = visit_varinfo_impl(visitor, fd.svar)
  let new_formals = fd.sformals.map(fn(vi) { visit_varinfo_impl(visitor, vi) })
  let new_locals = fd.slocals.map(fn(vi) { visit_varinfo_impl(visitor, vi) })
  let new_body = visit_block_impl(visitor, fd.sbody)
  {
    ..fd,
    svar: new_svar,
    sformals: new_formals,
    slocals: new_locals,
    sbody: new_body,
  }
}

///|
fn[V : CilVisitor] visit_block_impl(visitor : V, block : Block) -> Block {
  let new_stmts = block.bstmts.map(fn(s) { visit_stmt_impl(visitor, s) })
  { ..block, bstmts: new_stmts }
}

///|
fn[V : CilVisitor] visit_stmt_impl(visitor : V, s : Stmt) -> Stmt {
  match visitor.visit_stmt(s) {
    SkipChildren => s
    DoChildren => visit_stmt_children(visitor, s)
    ChangeTo(new_s) => new_s
    ChangeDoChildrenPost(new_s, post) =>
      post(visit_stmt_children(visitor, new_s))
  }
}

///|
fn[V : CilVisitor] visit_stmt_children(visitor : V, s : Stmt) -> Stmt {
  let new_kind = match s.skind {
    Instr(instrs) => {
      let new_instrs = []
      for i in instrs {
        let result = visit_instr_impl(visitor, i)
        for new_i in result {
          new_instrs.push(new_i)
        }
      }
      Instr(new_instrs)
    }
    Return(exp_opt, loc) => {
      let new_exp = exp_opt.map(fn(e) { visit_exp_impl(visitor, e) })
      Return(new_exp, loc)
    }
    Goto(target, loc) => Goto(target, loc)
    ComputedGoto(exp, loc) => {
      let new_exp = visit_exp_impl(visitor, exp)
      ComputedGoto(new_exp, loc)
    }
    Break(loc) => Break(loc)
    Continue(loc) => Continue(loc)
    If(cond, then_block, else_block, loc) => {
      let new_cond = visit_exp_impl(visitor, cond)
      let new_then = visit_block_impl(visitor, then_block)
      let new_else = visit_block_impl(visitor, else_block)
      If(new_cond, new_then, new_else, loc)
    }
    Switch(exp, block, cases, loc) => {
      let new_exp = visit_exp_impl(visitor, exp)
      let new_block = visit_block_impl(visitor, block)
      let new_cases = cases.map(fn(c) { visit_stmt_impl(visitor, c) })
      Switch(new_exp, new_block, new_cases, loc)
    }
    Loop(block, loc, cont, brk) => {
      let new_block = visit_block_impl(visitor, block)
      Loop(new_block, loc, cont, brk)
    }
    Block(block) => {
      let new_block = visit_block_impl(visitor, block)
      Block(new_block)
    }
    TryFinally(try_block, finally_block, loc) => {
      let new_try = visit_block_impl(visitor, try_block)
      let new_finally = visit_block_impl(visitor, finally_block)
      TryFinally(new_try, new_finally, loc)
    }
    TryExcept(try_block, (instrs, exp), except_block, loc) => {
      let new_try = visit_block_impl(visitor, try_block)
      let new_instrs : Array[Instr] = []
      for i in instrs {
        let result = visit_instr_impl(visitor, i)
        for new_i in result {
          new_instrs.push(new_i)
        }
      }
      let new_exp = visit_exp_impl(visitor, exp)
      let new_except = visit_block_impl(visitor, except_block)
      TryExcept(new_try, (new_instrs, new_exp), new_except, loc)
    }
  }
  { ..s, skind: new_kind }
}

///|
fn[V : CilVisitor] visit_instr_impl(visitor : V, i : Instr) -> Array[Instr] {
  match visitor.visit_instr(i) {
    SkipChildren => [i]
    DoChildren => [visit_instr_children(visitor, i)]
    ChangeTo(new_is) => new_is
    ChangeDoChildrenPost(new_is, post) =>
      post(new_is.map(i2 => visit_instr_children(visitor, i2)))
  }
}

///|
fn[V : CilVisitor] visit_instr_children(visitor : V, i : Instr) -> Instr {
  match i {
    Set(lv, exp, loc) => {
      let new_lv = visit_lval_impl(visitor, lv)
      let new_exp = visit_exp_impl(visitor, exp)
      Set(new_lv, new_exp, loc)
    }
    Call(lv_opt, func, args, loc) => {
      let new_lv = lv_opt.map(lv => visit_lval_impl(visitor, lv))
      let new_func = visit_exp_impl(visitor, func)
      let new_args = args.map(arg => visit_exp_impl(visitor, arg))
      Call(new_lv, new_func, new_args, loc)
    }
    Asm(attrs, templates, outputs, inputs, clobbers, loc) => {
      let new_outputs = outputs.map(o => {
        let (name, constraint, lv) = o
        (name, constraint, visit_lval_impl(visitor, lv))
      })
      let new_inputs = inputs.map(inp => {
        let (name, constraint, exp) = inp
        (name, constraint, visit_exp_impl(visitor, exp))
      })
      Asm(attrs, templates, new_outputs, new_inputs, clobbers, loc)
    }
  }
}

///|
fn[V : CilVisitor] visit_exp_impl(visitor : V, e : Exp) -> Exp {
  match visitor.visit_exp(e) {
    SkipChildren => e
    DoChildren => visit_exp_children(visitor, e)
    ChangeTo(new_e) => new_e
    ChangeDoChildrenPost(new_e, post) =>
      post(visit_exp_children(visitor, new_e))
  }
}

///|
fn[V : CilVisitor] visit_exp_children(visitor : V, e : Exp) -> Exp {
  match e {
    Const(_) => e
    Lval(lv) => Lval(visit_lval_impl(visitor, lv))
    SizeOf(t) => SizeOf(visit_type_impl(visitor, t))
    SizeOfE(exp) => SizeOfE(visit_exp_impl(visitor, exp))
    SizeOfStr(_) => e
    AlignOf(t) => AlignOf(visit_type_impl(visitor, t))
    AlignOfE(exp) => AlignOfE(visit_exp_impl(visitor, exp))
    UnOp(op, exp, t) => {
      let new_exp = visit_exp_impl(visitor, exp)
      let new_t = visit_type_impl(visitor, t)
      UnOp(op, new_exp, new_t)
    }
    BinOp(op, e1, e2, t) => {
      let new_e1 = visit_exp_impl(visitor, e1)
      let new_e2 = visit_exp_impl(visitor, e2)
      let new_t = visit_type_impl(visitor, t)
      BinOp(op, new_e1, new_e2, new_t)
    }
    Question(cond, e1, e2, t) => {
      let new_cond = visit_exp_impl(visitor, cond)
      let new_e1 = visit_exp_impl(visitor, e1)
      let new_e2 = visit_exp_impl(visitor, e2)
      let new_t = visit_type_impl(visitor, t)
      Question(new_cond, new_e1, new_e2, new_t)
    }
    CastE(t, exp) => {
      let new_t = visit_type_impl(visitor, t)
      let new_exp = visit_exp_impl(visitor, exp)
      CastE(new_t, new_exp)
    }
    AddrOf(lv) => AddrOf(visit_lval_impl(visitor, lv))
    AddrOfLabel(_) => e
    StartOf(lv) => StartOf(visit_lval_impl(visitor, lv))
  }
}

///|
fn[V : CilVisitor] visit_lval_impl(visitor : V, lv : LVal) -> LVal {
  match visitor.visit_lval(lv) {
    SkipChildren => lv
    DoChildren => visit_lval_children(visitor, lv)
    ChangeTo(new_lv) => new_lv
    ChangeDoChildrenPost(new_lv, post) =>
      post(visit_lval_children(visitor, new_lv))
  }
}

///|
fn[V : CilVisitor] visit_lval_children(visitor : V, lv : LVal) -> LVal {
  let new_host = match lv.host {
    Var(vi) => Var(visit_varinfo_impl(visitor, vi))
    Mem(exp) => Mem(visit_exp_impl(visitor, exp))
  }
  let new_offset = visit_offset_impl(visitor, lv.offset)
  { host: new_host, offset: new_offset }
}

///|
fn[V : CilVisitor] visit_type_impl(visitor : V, t : Typ) -> Typ {
  match visitor.visit_type(t) {
    SkipChildren => t
    DoChildren => visit_type_children(visitor, t)
    ChangeTo(new_t) => new_t
    ChangeDoChildrenPost(new_t, post) =>
      post(visit_type_children(visitor, new_t))
  }
}

///|
fn[V : CilVisitor] visit_type_children(visitor : V, t : Typ) -> Typ {
  match t {
    TVoid(_) => t
    TInt(_, _) => t
    TFloat(_, _) => t
    TPtr(base, attrs) => TPtr(visit_type_impl(visitor, base), attrs)
    TArray(base, len, attrs) => {
      let new_base = visit_type_impl(visitor, base)
      let new_len = len.map(fn(e) { visit_exp_impl(visitor, e) })
      TArray(new_base, new_len, attrs)
    }
    TFun(ret, params, vararg, attrs) => {
      let new_ret = visit_type_impl(visitor, ret)
      let new_params = params.map(ps => ps.map(fn(p) {
        let (name, pt, pattrs) = p
        (name, visit_type_impl(visitor, pt), pattrs)
      }))
      TFun(new_ret, new_params, vararg, attrs)
    }
    TNamed(ti, attrs) => {
      let new_ttype = visit_type_impl(visitor, ti.ttype)
      TNamed({ ..ti, ttype: new_ttype }, attrs)
    }
    TComp(_, _) | TEnum(_, _) | TBuiltinVaList(_) => t
  }
}

///|
fn[V : CilVisitor] visit_varinfo_impl(visitor : V, vi : VarInfo) -> VarInfo {
  match visitor.visit_varinfo(vi) {
    SkipChildren => vi
    DoChildren => {
      let new_type = visit_type_impl(visitor, vi.vtype)
      { ..vi, vtype: new_type }
    }
    ChangeTo(new_vi) => new_vi
    ChangeDoChildrenPost(new_vi, post) => {
      let new_type = visit_type_impl(visitor, new_vi.vtype)
      post({ ..new_vi, vtype: new_type })
    }
  }
}

///|
fn[V : CilVisitor] visit_offset_impl(visitor : V, off : Offset) -> Offset {
  match visitor.visit_offset(off) {
    SkipChildren => off
    DoChildren => visit_offset_children(visitor, off)
    ChangeTo(new_off) => new_off
    ChangeDoChildrenPost(new_off, post) =>
      post(visit_offset_children(visitor, new_off))
  }
}

///|
fn[V : CilVisitor] visit_offset_children(visitor : V, off : Offset) -> Offset {
  match off {
    NoOffset => NoOffset
    Field(fi, rest) => Field(fi, visit_offset_impl(visitor, rest))
    Index(exp, rest) => {
      let new_exp = visit_exp_impl(visitor, exp)
      Index(new_exp, visit_offset_impl(visitor, rest))
    }
  }
}

///|
fn[V : CilVisitor] visit_init_impl(
  visitor : V,
  vi : VarInfo,
  off : Offset,
  init : Init,
) -> Init {
  match visitor.visit_init(vi, off, init) {
    SkipChildren => init
    DoChildren => visit_init_children(visitor, vi, off, init)
    ChangeTo(new_init) => new_init
    ChangeDoChildrenPost(new_init, post) =>
      post(visit_init_children(visitor, vi, off, new_init))
  }
}

///|
fn[V : CilVisitor] visit_init_children(
  visitor : V,
  vi : VarInfo,
  _off : Offset,
  init : Init,
) -> Init {
  match init {
    SingleInit(exp) => SingleInit(visit_exp_impl(visitor, exp))
    CompoundInit(t, inits) => {
      let new_t = visit_type_impl(visitor, t)
      let new_inits = inits.map(item => {
        let (item_off, item_init) = item
        let new_off = visit_offset_impl(visitor, item_off)
        let new_init = visit_init_impl(visitor, vi, new_off, item_init)
        (new_off, new_init)
      })
      CompoundInit(new_t, new_inits)
    }
  }
}

///|
fn[V : CilVisitor] visit_attr_impl(
  visitor : V,
  attr : Attribute,
) -> Array[Attribute] {
  match visitor.visit_attr(attr) {
    SkipChildren => [attr]
    DoChildren => [attr]
    ChangeTo(new_attrs) => new_attrs
    ChangeDoChildrenPost(new_attrs, post) => post(new_attrs)
  }
}

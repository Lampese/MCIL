///|
let temp_counter : Ref[Int] = Ref::new(0)

///|
fn new_temp_name() -> String {
  let n = temp_counter.val
  temp_counter.val = n + 1
  "__tmp\{n}"
}

///|
pub struct SimplifyContext {
  fundec : @cil.FunDec
  instrs : Array[@cil.Instr]
  mut loc : @cil.Location
}

///|
pub fn SimplifyContext::new(
  fundec : @cil.FunDec,
  loc : @cil.Location,
) -> SimplifyContext {
  { fundec, instrs: [], loc }
}

///|
fn set_temp(ctx : SimplifyContext, e : @cil.Exp) -> @cil.Exp {
  let typ = @cil.type_of(e)
  let tmp = @cil.make_temp_var(ctx.fundec, new_temp_name(), typ)
  let lv = @cil.LVal::{
    host: @cil.LHost::Var(tmp),
    offset: @cil.Offset::NoOffset,
  }
  ctx.instrs.push(@cil.Set(lv, e, ctx.loc))
  @cil.Lval(lv)
}

///|
fn is_basic(e : @cil.Exp) -> Bool {
  match e {
    @cil.Const(_) => true
    @cil.AddrOf(lv) =>
      match (lv.host, lv.offset) {
        (@cil.LHost::Var(_), @cil.Offset::NoOffset) => true
        _ => false
      }
    @cil.StartOf(lv) =>
      match (lv.host, lv.offset) {
        (@cil.LHost::Var(_), @cil.Offset::NoOffset) => true
        _ => false
      }
    @cil.Lval(lv) =>
      match lv.host {
        @cil.LHost::Var(_) => true
        _ => false
      }
    @cil.SizeOf(_) => true
    @cil.SizeOfE(_) => true
    @cil.SizeOfStr(_) => true
    @cil.AlignOf(_) => true
    @cil.AlignOfE(_) => true
    _ => false
  }
}

///|
pub fn make_three_address(ctx : SimplifyContext, e : @cil.Exp) -> @cil.Exp {
  match e {
    @cil.Const(_) => e
    @cil.SizeOf(_) => e
    @cil.SizeOfE(_) => e
    @cil.SizeOfStr(_) => e
    @cil.AlignOf(_) => e
    @cil.AlignOfE(_) => e
    @cil.AddrOf(lv) =>
      match (lv.host, lv.offset) {
        (@cil.LHost::Var(_), @cil.Offset::NoOffset) => e
        (@cil.LHost::Mem(a), @cil.Offset::NoOffset) => a
        _ => @cil.AddrOf(simplify_lval(ctx, lv))
      }
    @cil.StartOf(lv) =>
      match (lv.host, lv.offset) {
        (@cil.LHost::Var(_), @cil.Offset::NoOffset) => e
        _ => {
          let slv = simplify_lval(ctx, lv)
          @cil.AddrOf(
            @cil.add_offset_lval(
              slv,
              @cil.Offset::Index(@cil.zero(), @cil.Offset::NoOffset),
            ),
          )
        }
      }
    @cil.Lval(lv) => @cil.Lval(simplify_lval(ctx, lv))
    @cil.BinOp(op, e1, e2, typ) => {
      let b1 = make_basic(ctx, e1)
      let b2 = make_basic(ctx, e2)
      @cil.BinOp(op, b1, b2, typ)
    }
    @cil.UnOp(op, e1, typ) => {
      let b1 = make_basic(ctx, e1)
      @cil.UnOp(op, b1, typ)
    }
    @cil.CastE(typ, e1) => {
      let b1 = make_basic(ctx, e1)
      @cil.CastE(typ, b1)
    }
    @cil.Question(cond, e1, e2, typ) => {
      let bc = make_basic(ctx, cond)
      let b1 = make_basic(ctx, e1)
      let b2 = make_basic(ctx, e2)
      @cil.Question(bc, b1, b2, typ)
    }
    _ => e
  }
}

///|
pub fn make_basic(ctx : SimplifyContext, e : @cil.Exp) -> @cil.Exp {
  let e2 = make_three_address(ctx, e)
  if is_basic(e2) {
    e2
  } else {
    set_temp(ctx, e2)
  }
}

///|
pub fn simplify_lval(ctx : SimplifyContext, lv : @cil.LVal) -> @cil.LVal {
  match lv.host {
    @cil.LHost::Var(v) => {
      let new_off = simplify_offset(ctx, lv.offset)
      @cil.LVal::{ host: @cil.LHost::Var(v), offset: new_off }
    }
    @cil.LHost::Mem(e) => {
      let basic_addr = make_basic(ctx, e)
      let new_off = simplify_offset(ctx, lv.offset)
      @cil.LVal::{ host: @cil.LHost::Mem(basic_addr), offset: new_off }
    }
  }
}

///|
fn simplify_offset(ctx : SimplifyContext, off : @cil.Offset) -> @cil.Offset {
  match off {
    @cil.Offset::NoOffset => @cil.Offset::NoOffset
    @cil.Offset::Field(fi, rest) =>
      @cil.Offset::Field(fi, simplify_offset(ctx, rest))
    @cil.Offset::Index(e, rest) => {
      let basic_idx = make_basic(ctx, e)
      @cil.Offset::Index(basic_idx, simplify_offset(ctx, rest))
    }
  }
}

///|
pub fn simplify_instr(
  ctx : SimplifyContext,
  i : @cil.Instr,
) -> Array[@cil.Instr] {
  ctx.instrs.clear()
  match i {
    @cil.Set(lv, e, loc) => {
      ctx.loc = loc
      let slv = simplify_lval(ctx, lv)
      let se = make_three_address(ctx, e)
      let result = ctx.instrs.copy()
      result.push(@cil.Set(slv, se, loc))
      result
    }
    @cil.Call(lv_opt, fn_exp, args, loc) => {
      ctx.loc = loc
      let slv_opt = lv_opt.map(fn(lv) { simplify_lval(ctx, lv) })
      let sfn = make_basic(ctx, fn_exp)
      let sargs = args.map(fn(a) { make_basic(ctx, a) })
      let result = ctx.instrs.copy()
      result.push(@cil.Call(slv_opt, sfn, sargs, loc))
      result
    }
    @cil.Asm(_, _, _, _, _, _) => [i]
  }
}

///|
pub fn simplify_stmt(fundec : @cil.FunDec, s : @cil.Stmt) -> Unit {
  match s.skind {
    @cil.Instr(instrs) => {
      let ctx = SimplifyContext::new(fundec, @cil.unknown_loc)
      let new_instrs = []
      for i in instrs {
        new_instrs.append(simplify_instr(ctx, i))
      }
      s.skind = @cil.Instr(new_instrs)
    }
    @cil.Return(Some(e), loc) => {
      let ctx = SimplifyContext::new(fundec, loc)
      let se = make_basic(ctx, e)
      s.skind = @cil.Return(Some(se), loc)
    }
    @cil.If(cond, then_block, else_block, loc) => {
      let ctx = SimplifyContext::new(fundec, loc)
      let scond = make_basic(ctx, cond)
      simplify_block(fundec, then_block)
      simplify_block(fundec, else_block)
      s.skind = @cil.If(scond, then_block, else_block, loc)
    }
    @cil.Switch(cond, body, cases, loc) => {
      let ctx = SimplifyContext::new(fundec, loc)
      let scond = make_basic(ctx, cond)
      simplify_block(fundec, body)
      s.skind = @cil.Switch(scond, body, cases, loc)
    }
    @cil.Loop(body, _, _, _) => simplify_block(fundec, body)
    @cil.Block(b) => simplify_block(fundec, b)
    _ => ()
  }
}

///|
pub fn simplify_block(fundec : @cil.FunDec, b : @cil.Block) -> Unit {
  for s in b.bstmts {
    simplify_stmt(fundec, s)
  }
}

///|
pub fn simplify_fundec(f : @cil.FunDec) -> Unit {
  simplify_block(f, f.sbody)
}

///|
pub fn simplify_file(file : @cil.File) -> Unit {
  @cil.iter_globals(file, fn(g) {
    match g {
      @cil.GFun(fd, _) => simplify_fundec(fd)
      _ => ()
    }
  })
}

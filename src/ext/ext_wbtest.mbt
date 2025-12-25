///|
test "oneret: simple function" {
  let ret_type = @cil.int_type()
  let svar = @cil.make_global_var(
    "test_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let loc = @cil.unknown_loc
  let ret1 = @cil.mk_stmt(@cil.Return(Some(@cil.one()), loc))
  let ret2 = @cil.mk_stmt(@cil.Return(Some(@cil.zero()), loc))
  let block = @cil.Block::{ battrs: [], bstmts: [ret1, ret2] }
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [],
    smaxid: 0,
    sbody: block,
    smaxstmtid: None,
    sallstmts: [],
  }
  oneret(fundec)
  let stmts = fundec.sbody.bstmts
  inspect(stmts.length() > 0, content="true")
}

///|
test "oneret: void function" {
  let ret_type = @cil.void_type()
  let svar = @cil.make_global_var(
    "void_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let loc = @cil.unknown_loc
  let ret = @cil.mk_stmt(@cil.Return(None, loc))
  let block = @cil.Block::{ battrs: [], bstmts: [ret] }
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [],
    smaxid: 0,
    sbody: block,
    smaxstmtid: None,
    sallstmts: [],
  }
  oneret(fundec)
  inspect(fundec.sbody.bstmts.length() >= 1, content="true")
}

///|
test "simplify: basic expression already simplified" {
  let ret_type = @cil.int_type()
  let svar = @cil.make_global_var(
    "test_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [],
    smaxid: 0,
    sbody: @cil.Block::{ battrs: [], bstmts: [] },
    smaxstmtid: None,
    sallstmts: [],
  }
  let ctx = SimplifyContext::new(fundec, @cil.unknown_loc)
  let const_exp = @cil.one()
  let _ = make_basic(ctx, const_exp)
  inspect(ctx.instrs.length(), content="0")
}

///|
test "simplify: complex expression needs temp" {
  let ret_type = @cil.int_type()
  let svar = @cil.make_global_var(
    "test_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [],
    smaxid: 0,
    sbody: @cil.Block::{ battrs: [], bstmts: [] },
    smaxstmtid: None,
    sallstmts: [],
  }
  let ctx = SimplifyContext::new(fundec, @cil.unknown_loc)
  let binop_exp = @cil.BinOp(
    @cil.PlusA,
    @cil.one(),
    @cil.zero(),
    @cil.int_type(),
  )
  let _ = make_basic(ctx, binop_exp)
  inspect(ctx.instrs.length(), content="1")
}

///|
test "simplify: nested expression" {
  let ret_type = @cil.int_type()
  let svar = @cil.make_global_var(
    "test_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [],
    smaxid: 0,
    sbody: @cil.Block::{ battrs: [], bstmts: [] },
    smaxstmtid: None,
    sallstmts: [],
  }
  let ctx = SimplifyContext::new(fundec, @cil.unknown_loc)
  let inner = @cil.BinOp(
    @cil.PlusA,
    @cil.one(),
    @cil.integer(2),
    @cil.int_type(),
  )
  let outer = @cil.BinOp(@cil.PlusA, inner, @cil.integer(3), @cil.int_type())
  let result = make_three_address(ctx, outer)
  let is_binop = match result {
    @cil.BinOp(_, _, _, _) => true
    _ => false
  }
  inspect(is_binop, content="true")
}

///|
test "simplify: instruction simplification" {
  let ret_type = @cil.int_type()
  let svar = @cil.make_global_var(
    "test_fn",
    @cil.TFun(ret_type, None, false, []),
  )
  let x_var = @cil.make_local_var("x", @cil.int_type())
  let fundec = @cil.FunDec::{
    svar,
    sformals: [],
    slocals: [x_var],
    smaxid: 0,
    sbody: @cil.Block::{ battrs: [], bstmts: [] },
    smaxstmtid: None,
    sallstmts: [],
  }
  let ctx = SimplifyContext::new(fundec, @cil.unknown_loc)
  let lv = @cil.LVal::{
    host: @cil.LHost::Var(x_var),
    offset: @cil.Offset::NoOffset,
  }
  let rhs = @cil.BinOp(@cil.PlusA, @cil.one(), @cil.integer(2), @cil.int_type())
  let instr = @cil.Set(lv, rhs, @cil.unknown_loc)
  let result = simplify_instr(ctx, instr)
  inspect(result.length(), content="1")
}

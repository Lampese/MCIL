///|
pub enum CtxType {
  CTStruct
  CTUnion
  CTFArg
  CTFRes
  CTArray
  CTPtr
  CTExp
  CTSizeof
  CTDecl
} derive(Show)

///|
pub struct CheckError {
  message : String
  loc_file : String
  loc_line : Int
}

///|
pub struct Checker {
  errors : Array[CheckError]
  mut current_function : VarInfo?
  mut current_return_type : Typ?
  defined_vars : Map[Int, VarInfo]
  defined_labels : Map[String, Bool]
  goto_targets : Array[(String, Stmt)]
}

///|
pub fn Checker::new() -> Checker {
  {
    errors: [],
    current_function: None,
    current_return_type: None,
    defined_vars: Map::new(),
    defined_labels: Map::new(),
    goto_targets: [],
  }
}

///|
fn warn(checker : Checker, loc : Location, msg : String) -> Unit {
  checker.errors.push({ message: msg, loc_file: loc.file, loc_line: loc.line })
}

///|
pub fn check_type_context(
  checker : Checker,
  t : Typ,
  ctx : CtxType,
  loc : Location,
) -> Bool {
  match t {
    TVoid(_) =>
      match ctx {
        CTPtr | CTFRes | CTDecl | CTSizeof => true
        _ => {
          warn(checker, loc, "void type used in invalid context: \{ctx}")
          false
        }
      }
    TArray(_, _, _) =>
      match ctx {
        CTStruct | CTUnion | CTSizeof | CTDecl | CTArray | CTPtr => true
        _ => {
          warn(checker, loc, "array type used in invalid context: \{ctx}")
          false
        }
      }
    TFun(_, _, _, _) =>
      match ctx {
        CTPtr | CTDecl | CTSizeof => true
        _ => {
          warn(checker, loc, "function type used in invalid context: \{ctx}")
          false
        }
      }
    _ => true
  }
}

///|
pub fn check_type(
  checker : Checker,
  t : Typ,
  ctx : CtxType,
  loc : Location,
) -> Unit {
  let _ = check_type_context(checker, t, ctx, loc)
  match t {
    TVoid(attrs) => check_attributes(checker, attrs, loc)
    TInt(_, attrs) => check_attributes(checker, attrs, loc)
    TFloat(_, attrs) => check_attributes(checker, attrs, loc)
    TPtr(inner, attrs) => {
      check_attributes(checker, attrs, loc)
      check_type(checker, inner, CTPtr, loc)
    }
    TArray(elem, len_opt, attrs) => {
      check_attributes(checker, attrs, loc)
      check_type(checker, elem, CTArray, loc)
      match len_opt {
        Some(len) => {
          let len_type = check_exp(checker, len, loc)
          if not(is_integral_type(len_type)) {
            warn(checker, loc, "array length must be integral type")
          }
        }
        None => ()
      }
    }
    TFun(ret, args_opt, _, attrs) => {
      check_attributes(checker, attrs, loc)
      check_type(checker, ret, CTFRes, loc)
      match args_opt {
        Some(args) =>
          for arg in args {
            let (_, arg_type, arg_attrs) = arg
            check_type(checker, arg_type, CTFArg, loc)
            check_attributes(checker, arg_attrs, loc)
          }
        None => ()
      }
    }
    TNamed(ti, attrs) => {
      check_attributes(checker, attrs, loc)
      if ti.tname == "" {
        warn(checker, loc, "empty type name in TNamed")
      }
    }
    TComp(ci, attrs) => {
      check_attributes(checker, attrs, loc)
      if ci.cname == "" {
        warn(checker, loc, "empty name in CompInfo")
      }
    }
    TEnum(ei, attrs) => {
      check_attributes(checker, attrs, loc)
      if ei.ename == "" {
        warn(checker, loc, "empty name in EnumInfo")
      }
    }
    TBuiltinVaList(attrs) => check_attributes(checker, attrs, loc)
  }
}

///|
pub fn check_attributes(
  checker : Checker,
  attrs : Array[Attribute],
  loc : Location,
) -> Unit {
  let mut last_name = ""
  for attr in attrs {
    if attr.name < last_name {
      warn(
        checker,
        loc,
        "attributes not sorted: \{last_name} before \{attr.name}",
      )
    }
    last_name = attr.name
  }
}

///|
pub fn check_exp(checker : Checker, e : Exp, loc : Location) -> Typ {
  match e {
    Const(c) =>
      match c {
        CInt64(_, ik, _) => TInt(ik, [])
        CStr(_) => TPtr(TInt(IChar, []), [])
        CWStr(_) => TPtr(TInt(IInt, []), [])
        CChr(_) => TInt(IChar, [])
        CReal(_, fk, _) => TFloat(fk, [])
        CEnum(_, _, ei) => TEnum(ei, [])
      }
    Lval(lv) => check_lval(checker, lv, loc)
    SizeOf(t) => {
      check_type(checker, t, CTSizeof, loc)
      uint_type()
    }
    SizeOfE(inner) => {
      let _ = check_exp(checker, inner, loc)
      uint_type()
    }
    SizeOfStr(_) => uint_type()
    AlignOf(t) => {
      check_type(checker, t, CTSizeof, loc)
      uint_type()
    }
    AlignOfE(inner) => {
      let _ = check_exp(checker, inner, loc)
      uint_type()
    }
    UnOp(op, inner, result_type) => {
      let inner_type = check_exp(checker, inner, loc)
      check_type(checker, result_type, CTExp, loc)
      match op {
        Neg | BNot =>
          if not(is_integral_type(inner_type)) && not(is_float_type(inner_type)) {
            warn(checker, loc, "arithmetic operator on non-arithmetic type")
          }
        LNot =>
          if not(is_scalar_type(inner_type)) {
            warn(checker, loc, "logical not on non-scalar type")
          }
      }
      result_type
    }
    BinOp(op, e1, e2, result_type) => {
      let t1 = check_exp(checker, e1, loc)
      let t2 = check_exp(checker, e2, loc)
      check_type(checker, result_type, CTExp, loc)
      match op {
        PlusA | MinusA | Mult | Div =>
          if not(is_arithmetic_type(t1)) || not(is_arithmetic_type(t2)) {
            warn(checker, loc, "arithmetic operator on non-arithmetic types")
          }
        Mod | BAnd | BOr | BXor | Shiftlt | Shiftrt =>
          if not(is_integral_type(t1)) || not(is_integral_type(t2)) {
            warn(checker, loc, "integral operator on non-integral types")
          }
        Lt | Gt | Le | Ge | Eq | Ne => ()
        LAnd | LOr =>
          if not(is_scalar_type(t1)) || not(is_scalar_type(t2)) {
            warn(checker, loc, "logical operator on non-scalar types")
          }
        PlusPI | IndexPI | MinusPI =>
          if not(is_pointer_type(t1)) {
            warn(checker, loc, "pointer arithmetic requires pointer type")
          }
        MinusPP =>
          if not(is_pointer_type(t1)) || not(is_pointer_type(t2)) {
            warn(checker, loc, "pointer subtraction requires two pointers")
          }
      }
      result_type
    }
    Question(cond, then_e, else_e, result_type) => {
      let cond_type = check_exp(checker, cond, loc)
      if not(is_scalar_type(cond_type)) {
        warn(checker, loc, "conditional expression requires scalar condition")
      }
      let _ = check_exp(checker, then_e, loc)
      let _ = check_exp(checker, else_e, loc)
      result_type
    }
    CastE(target_type, inner) => {
      check_type(checker, target_type, CTExp, loc)
      let _ = check_exp(checker, inner, loc)
      target_type
    }
    AddrOf(lv) => {
      let lv_type = check_lval(checker, lv, loc)
      TPtr(lv_type, [])
    }
    AddrOfLabel(_) => TPtr(TVoid([]), [])
    StartOf(lv) => {
      let lv_type = check_lval(checker, lv, loc)
      match unroll_type(lv_type) {
        TArray(elem, _, _) => TPtr(elem, [])
        _ => {
          warn(checker, loc, "StartOf applied to non-array type")
          TPtr(TVoid([]), [])
        }
      }
    }
  }
}

///|
pub fn check_lval(checker : Checker, lv : LVal, loc : Location) -> Typ {
  let base_type = match lv.host {
    Var(vi) => {
      match checker.defined_vars.get(vi.vid) {
        Some(defined_vi) =>
          if vi.vname != defined_vi.vname {
            warn(
              checker,
              loc,
              "variable id \{vi.vid} has inconsistent names: \{vi.vname} vs \{defined_vi.vname}",
            )
          }
        None =>
          warn(checker, loc, "undefined variable: \{vi.vname} (id \{vi.vid})")
      }
      vi.vtype
    }
    Mem(addr) => {
      let addr_type = check_exp(checker, addr, loc)
      match unroll_type(addr_type) {
        TPtr(pointee, _) => pointee
        _ => {
          warn(checker, loc, "dereferencing non-pointer type")
          TVoid([])
        }
      }
    }
  }
  check_offset(checker, base_type, lv.offset, loc)
}

///|
pub fn check_offset(
  checker : Checker,
  base_type : Typ,
  off : Offset,
  loc : Location,
) -> Typ {
  match off {
    NoOffset => base_type
    Field(fi, rest) => {
      match unroll_type(base_type) {
        TComp(ci, _) =>
          if fi.fcomp.ckey != ci.ckey {
            warn(
              checker,
              loc,
              "field \{fi.fname} does not belong to comp \{ci.cname}",
            )
          }
        _ => warn(checker, loc, "field access on non-composite type")
      }
      check_offset(checker, fi.ftype, rest, loc)
    }
    Index(idx, rest) => {
      let idx_type = check_exp(checker, idx, loc)
      if not(is_integral_type(idx_type)) {
        warn(checker, loc, "array index must be integral type")
      }
      match unroll_type(base_type) {
        TArray(elem, _, _) => check_offset(checker, elem, rest, loc)
        TPtr(pointee, _) => check_offset(checker, pointee, rest, loc)
        _ => {
          warn(checker, loc, "indexing non-array/pointer type")
          base_type
        }
      }
    }
  }
}

///|
pub fn check_instr(checker : Checker, i : Instr) -> Unit {
  match i {
    Set(lv, e, loc) => {
      let lv_type = check_lval(checker, lv, loc)
      let e_type = check_exp(checker, e, loc)
      check_type_compatible(checker, lv_type, e_type, loc)
    }
    Call(lv_opt, fn_exp, args, loc) => {
      let fn_type = check_exp(checker, fn_exp, loc)
      match unroll_type(fn_type) {
        TFun(ret_type, params_opt, is_vararg, _) => {
          match lv_opt {
            Some(lv) => {
              let lv_type = check_lval(checker, lv, loc)
              check_type_compatible(checker, lv_type, ret_type, loc)
            }
            None => ()
          }
          match params_opt {
            Some(params) => {
              if not(is_vararg) && args.length() != params.length() {
                warn(
                  checker,
                  loc,
                  "wrong number of arguments: expected \{params.length()}, got \{args.length()}",
                )
              }
              for i, arg in args {
                let arg_type = check_exp(checker, arg, loc)
                if i < params.length() {
                  let (_, param_type, _) = params[i]
                  check_type_compatible(checker, param_type, arg_type, loc)
                }
              }
            }
            None =>
              for arg in args {
                let _ = check_exp(checker, arg, loc)

              }
          }
        }
        TPtr(inner, _) =>
          match unroll_type(inner) {
            TFun(_, _, _, _) => ()
            _ => warn(checker, loc, "calling non-function type")
          }
        _ => warn(checker, loc, "calling non-function type")
      }
    }
    Asm(_, _, _, _, _, _) => ()
  }
}

///|
pub fn check_type_compatible(
  checker : Checker,
  t1 : Typ,
  t2 : Typ,
  loc : Location,
) -> Unit {
  let cat1 = type_category(t1)
  let cat2 = type_category(t2)
  if cat1 != cat2 && cat1 != "void" && cat2 != "void" {
    if not((cat1 == "int" && cat2 == "ptr") || (cat1 == "ptr" && cat2 == "int")) {
      warn(checker, loc, "type mismatch: \{cat1} vs \{cat2}")
    }
  }
}

///|
fn type_category(t : Typ) -> String {
  match unroll_type(t) {
    TVoid(_) => "void"
    TInt(_, _) => "int"
    TFloat(_, _) => "float"
    TPtr(_, _) => "ptr"
    TArray(_, _, _) => "array"
    TFun(_, _, _, _) => "fun"
    TComp(ci, _) => if ci.cstruct { "struct" } else { "union" }
    TEnum(_, _) => "enum"
    _ => "other"
  }
}

///|
pub fn check_stmt(checker : Checker, s : Stmt) -> Unit {
  for label in s.labels {
    match label {
      Label::Label(name, _, _) => checker.defined_labels.set(name, true)
      _ => ()
    }
  }
  match s.skind {
    Instr(instrs) =>
      for i in instrs {
        check_instr(checker, i)
      }
    Return(exp_opt, loc) =>
      match (exp_opt, checker.current_return_type) {
        (Some(e), Some(ret_type)) => {
          let e_type = check_exp(checker, e, loc)
          check_type_compatible(checker, ret_type, e_type, loc)
        }
        (None, Some(ret_type)) =>
          match unroll_type(ret_type) {
            TVoid(_) => ()
            _ => warn(checker, loc, "missing return value in non-void function")
          }
        (Some(_), None) => warn(checker, loc, "return value in void function")
        (None, None) => ()
      }
    Goto(target, _) =>
      for label in target.labels {
        match label {
          Label::Label(name, _, _) => checker.goto_targets.push((name, target))
          _ => ()
        }
      }
    ComputedGoto(addr, loc) => {
      let addr_type = check_exp(checker, addr, loc)
      if not(is_pointer_type(addr_type)) {
        warn(checker, loc, "computed goto requires pointer type")
      }
    }
    Break(_) | Continue(_) => ()
    If(cond, then_block, else_block, loc) => {
      let cond_type = check_exp(checker, cond, loc)
      if not(is_scalar_type(cond_type)) {
        warn(checker, loc, "if condition must be scalar type")
      }
      check_block(checker, then_block)
      check_block(checker, else_block)
    }
    Switch(cond, body, _, loc) => {
      let cond_type = check_exp(checker, cond, loc)
      if not(is_integral_type(cond_type)) {
        warn(checker, loc, "switch condition must be integral type")
      }
      check_block(checker, body)
    }
    Loop(body, _, _, _) => check_block(checker, body)
    Block(b) => check_block(checker, b)
    TryFinally(try_block, finally_block, _) => {
      check_block(checker, try_block)
      check_block(checker, finally_block)
    }
    TryExcept(try_block, (filter_instrs, filter_exp), except_block, loc) => {
      check_block(checker, try_block)
      for i in filter_instrs {
        check_instr(checker, i)
      }
      let _ = check_exp(checker, filter_exp, loc)
      check_block(checker, except_block)
    }
  }
}

///|
pub fn check_block(checker : Checker, b : Block) -> Unit {
  check_attributes(checker, b.battrs, unknown_loc)
  for s in b.bstmts {
    check_stmt(checker, s)
  }
}

///|
pub fn check_fundec(checker : Checker, f : FunDec, loc : Location) -> Unit {
  checker.current_function = Some(f.svar)
  checker.current_return_type = match f.svar.vtype {
    TFun(ret, _, _, _) => Some(ret)
    _ => {
      warn(checker, loc, "function \{f.svar.vname} does not have function type")
      None
    }
  }
  for formal in f.sformals {
    checker.defined_vars.set(formal.vid, formal)
  }
  for local_var in f.slocals {
    checker.defined_vars.set(local_var.vid, local_var)
  }
  check_block(checker, f.sbody)
  for target in checker.goto_targets {
    let (name, _) = target
    match checker.defined_labels.get(name) {
      Some(_) => ()
      None => warn(checker, loc, "goto target label not found: \{name}")
    }
  }
  checker.current_function = None
  checker.current_return_type = None
  checker.defined_labels.clear()
  checker.goto_targets.clear()
  for formal in f.sformals {
    checker.defined_vars.remove(formal.vid)
  }
  for local_var in f.slocals {
    checker.defined_vars.remove(local_var.vid)
  }
}

///|
pub fn check_global(checker : Checker, g : Global) -> Unit {
  match g {
    GType(ti, loc) => {
      if ti.tname == "" {
        warn(checker, loc, "empty name in typedef")
      }
      check_type(checker, ti.ttype, CTDecl, loc)
    }
    GCompTag(ci, loc) => {
      if ci.cname == "" {
        warn(checker, loc, "empty name in struct/union definition")
      }
      for fi in ci.cfields {
        check_type(
          checker,
          fi.ftype,
          if ci.cstruct {
            CTStruct
          } else {
            CTUnion
          },
          loc,
        )
      }
    }
    GCompTagDecl(ci, loc) =>
      if ci.cname == "" {
        warn(checker, loc, "empty name in struct/union declaration")
      }
    GEnumTag(ei, loc) => {
      if ei.ename == "" {
        warn(checker, loc, "empty name in enum definition")
      }
      for item in ei.eitems {
        let (_, value, item_loc) = item
        let _ = check_exp(checker, value, item_loc)

      }
    }
    GEnumTagDecl(ei, loc) =>
      if ei.ename == "" {
        warn(checker, loc, "empty name in enum declaration")
      }
    GVarDecl(vi, loc) => {
      checker.defined_vars.set(vi.vid, vi)
      check_type(checker, vi.vtype, CTDecl, loc)
    }
    GVar(vi, init_info, loc) => {
      checker.defined_vars.set(vi.vid, vi)
      check_type(checker, vi.vtype, CTDecl, loc)
      match init_info.init {
        Some(init) => check_init(checker, init, vi.vtype, loc)
        None => ()
      }
    }
    GFun(fd, loc) => {
      checker.defined_vars.set(fd.svar.vid, fd.svar)
      check_type(checker, fd.svar.vtype, CTDecl, loc)
      check_fundec(checker, fd, loc)
    }
    GAsm(_, _) => ()
    GPragma(attr, loc) => check_attributes(checker, [attr], loc)
    GText(_) => ()
  }
}

///|
pub fn check_init(
  checker : Checker,
  init : Init,
  expected_type : Typ,
  loc : Location,
) -> Unit {
  match init {
    SingleInit(e) => {
      let e_type = check_exp(checker, e, loc)
      check_type_compatible(checker, expected_type, e_type, loc)
    }
    CompoundInit(t, items) => {
      check_type(checker, t, CTDecl, loc)
      for item in items {
        let (off, sub_init) = item
        let sub_type = type_of_offset(expected_type, off)
        check_init(checker, sub_init, sub_type, loc)
      }
    }
  }
}

///|
pub fn check_file(f : File) -> Array[CheckError] {
  let checker = Checker::new()
  for g in f.globals {
    check_global(checker, g)
  }
  checker.errors
}

///|
pub fn is_valid_file(f : File) -> Bool {
  check_file(f).is_empty()
}

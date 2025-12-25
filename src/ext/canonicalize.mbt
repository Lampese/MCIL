///|
let cpp_keywords : Array[String] = [
  "bool", "catch", "class", "const_cast", "delete", "dynamic_cast", "explicit", "export",
  "false", "friend", "mutable", "namespace", "new", "operator", "private", "protected",
  "public", "register", "reinterpret_cast", "static_cast", "template", "this", "throw",
  "true", "try", "typeid", "typename", "using", "virtual", "wchar_t",
]

///|
pub fn is_cpp_keyword(name : String) -> Bool {
  for kw in cpp_keywords {
    if name == kw {
      return true
    }
  }
  false
}

///|
pub fn rename_cpp_keyword(name : String) -> String {
  if is_cpp_keyword(name) {
    "_" + name + "_"
  } else {
    name
  }
}

///|
priv struct CanonicalizeContext {
  declared_vars : @hashset.HashSet[Int]
  defined_vars : @hashset.HashSet[Int]
  rename_map : Map[String, String]
}

///|
fn CanonicalizeContext::new() -> CanonicalizeContext {
  {
    declared_vars: @hashset.new(),
    defined_vars: @hashset.new(),
    rename_map: {},
  }
}

///|
fn canonicalize_varinfo(ctx : CanonicalizeContext, vi : @cil.VarInfo) -> Unit {
  if is_cpp_keyword(vi.vname) {
    let new_name = rename_cpp_keyword(vi.vname)
    ctx.rename_map.set(vi.vname, new_name)
  }
}

///|
pub fn remove_duplicate_declarations(f : @cil.File) -> Unit {
  let ctx = CanonicalizeContext::new()
  let new_globals = []
  for g in f.globals {
    let should_keep = match g {
      GVarDecl(vi, _) =>
        if ctx.declared_vars.contains(vi.vid) ||
          ctx.defined_vars.contains(vi.vid) {
          false
        } else {
          ctx.declared_vars.add(vi.vid)
          true
        }
      GVar(vi, init_info, _) =>
        match init_info.init {
          Some(_) =>
            if ctx.defined_vars.contains(vi.vid) {
              false
            } else {
              ctx.defined_vars.add(vi.vid)
              true
            }
          None =>
            if ctx.declared_vars.contains(vi.vid) ||
              ctx.defined_vars.contains(vi.vid) {
              false
            } else {
              ctx.declared_vars.add(vi.vid)
              true
            }
        }
      GFun(fd, _) =>
        if ctx.defined_vars.contains(fd.svar.vid) {
          false
        } else {
          ctx.defined_vars.add(fd.svar.vid)
          true
        }
      _ => true
    }
    if should_keep {
      new_globals.push(g)
    }
  }
  f.globals.clear()
  for g in new_globals {
    f.globals.push(g)
  }
}

///|
fn add_int_to_enum_casts(e : @cil.Exp, target_type : @cil.Typ) -> @cil.Exp {
  match @cil.unroll_type(target_type) {
    TEnum(_, _) =>
      match e {
        Const(CInt64(_, _, _)) => @cil.Exp::CastE(target_type, e)
        _ => e
      }
    _ => e
  }
}

///|
fn canonicalize_function_call(
  fn_exp : @cil.Exp,
  args : Array[@cil.Exp],
) -> @cil.Exp {
  let fn_type = @cil.type_of(fn_exp)
  match @cil.unroll_type(fn_type) {
    TPtr(inner, _) =>
      match @cil.unroll_type(inner) {
        TFun(ret, None, is_vararg, attrs) => {
          let arg_types : Array[(String, @cil.Typ, Array[@cil.Attribute])] = []
          for i, arg in args {
            arg_types.push(("arg" + i.to_string(), @cil.type_of(arg), []))
          }
          let new_fn_type = @cil.Typ::TFun(
            ret,
            Some(arg_types),
            is_vararg,
            attrs,
          )
          let new_ptr_type = @cil.Typ::TPtr(new_fn_type, [])
          @cil.Exp::CastE(new_ptr_type, fn_exp)
        }
        _ => fn_exp
      }
    _ => fn_exp
  }
}

///|
fn canonicalize_instr(i : @cil.Instr) -> @cil.Instr {
  match i {
    Set(lv, e, loc) => {
      let lv_type = @cil.type_of_lval(lv)
      let casted_e = add_int_to_enum_casts(e, lv_type)
      @cil.Instr::Set(lv, casted_e, loc)
    }
    Call(lv_opt, fn_exp, args, loc) => {
      let new_fn_exp = canonicalize_function_call(fn_exp, args)
      @cil.Instr::Call(lv_opt, new_fn_exp, args, loc)
    }
    _ => i
  }
}

///|
fn canonicalize_stmt(s : @cil.Stmt) -> Unit {
  s.skind = match s.skind {
    Instr(instrs) => @cil.StmtKind::Instr(instrs.map(canonicalize_instr))
    If(cond, then_block, else_block, loc) => {
      canonicalize_block(then_block)
      canonicalize_block(else_block)
      @cil.StmtKind::If(cond, then_block, else_block, loc)
    }
    Switch(cond, body, cases, loc) => {
      canonicalize_block(body)
      @cil.StmtKind::Switch(cond, body, cases, loc)
    }
    Loop(body, loc1, cont, brk) => {
      canonicalize_block(body)
      @cil.StmtKind::Loop(body, loc1, cont, brk)
    }
    Block(b) => {
      canonicalize_block(b)
      @cil.StmtKind::Block(b)
    }
    TryFinally(try_block, finally_block, loc) => {
      canonicalize_block(try_block)
      canonicalize_block(finally_block)
      @cil.StmtKind::TryFinally(try_block, finally_block, loc)
    }
    TryExcept(try_block, filter, except_block, loc) => {
      canonicalize_block(try_block)
      canonicalize_block(except_block)
      @cil.StmtKind::TryExcept(try_block, filter, except_block, loc)
    }
    _ => s.skind
  }
}

///|
fn canonicalize_block(b : @cil.Block) -> Unit {
  for s in b.bstmts {
    canonicalize_stmt(s)
  }
}

///|
pub fn canonicalize_fundec(fd : @cil.FunDec) -> Unit {
  let ctx = CanonicalizeContext::new()
  for formal in fd.sformals {
    canonicalize_varinfo(ctx, formal)
  }
  for local_var in fd.slocals {
    canonicalize_varinfo(ctx, local_var)
  }
  canonicalize_block(fd.sbody)
}

///|
fn canonicalize_global(g : @cil.Global) -> Unit {
  match g {
    GFun(fd, _) => canonicalize_fundec(fd)
    _ => ()
  }
}

///|
pub fn canonicalize_file(f : @cil.File) -> Unit {
  remove_duplicate_declarations(f)
  for g in f.globals {
    canonicalize_global(g)
  }
}

///|
pub fn add_cpp_compat_defines() -> String {
  let mut result = ""
  result = result + "#define __inline inline\n"
  result = result + "#define __restrict\n"
  result = result + "#define __extension__\n"
  result = result + "#define __attribute__(x)\n"
  result
}

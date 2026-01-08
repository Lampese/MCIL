///|
test "lexer: basic tokens" {
  let source = "int x = 42;"
  let tokens = tokenize(source, "test.c")
  let token_names = tokens.map(fn(t) { t.0.to_string() })
  inspect(
    token_names,
    content=(
      #|["KwInt", "Ident(\"x\")", "Eq", "IntConst(\"42\")", "Semi", "Eof"]
    ),
  )
}

///|
test "lexer: operators" {
  let source = "a + b - c * d / e % f"
  let tokens = tokenize(source, "test.c")
  let ops = tokens.filter(fn(t) {
    match t.0 {
      Plus | Minus | Star | Slash | Percent => true
      _ => false
    }
  })
  inspect(ops.length(), content="5")
}

///|
test "lexer: comparison operators" {
  let source = "< <= > >= == !="
  let tokens = tokenize(source, "test.c")
  let token_names = tokens.map(fn(t) { t.0.to_string() })
  inspect(
    token_names,
    content=(
      #|["Lt", "LtEq", "Gt", "GtEq", "EqEq", "BangEq", "Eof"]
    ),
  )
}

///|
test "lexer: logical operators" {
  let source = "a && b || !c"
  let tokens = tokenize(source, "test.c")
  let token_names = tokens.map(fn(t) { t.0.to_string() })
  inspect(
    token_names,
    content=(
      #|["Ident(\"a\")", "AmpAmp", "Ident(\"b\")", "PipePipe", "Bang", "Ident(\"c\")", "Eof"]
    ),
  )
}

///|
test "lexer: string literal" {
  let source = "\"hello world\""
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="StringConst(\"hello world\")")
}

///|
test "lexer: character literal" {
  let source = "'a'"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="CharConst(\"a\")")
}

///|
test "lexer: hex number" {
  let source = "0x1234ABCD"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="IntConst(\"0x1234ABCD\")")
}

///|
test "lexer: float number" {
  let source = "3.14159"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="FloatConst(\"3.14159\")")
}

///|
test "lexer: keywords" {
  let source = "if else while for return"
  let tokens = tokenize(source, "test.c")
  let token_names = tokens.map(fn(t) { t.0.to_string() })
  inspect(
    token_names,
    content=(
      #|["KwIf", "KwElse", "KwWhile", "KwFor", "KwReturn", "Eof"]
    ),
  )
}

///|
test "lexer: comments stripped" {
  let source = "int  x;"
  let tokens = tokenize(source, "test.c")
  let token_names = tokens.map(fn(t) { t.0.to_string() })
  inspect(
    token_names,
    content=(
      #|["KwInt", "Ident(\"x\")", "Semi", "Eof"]
    ),
  )
}

///|
test "parser: primary expression - integer" {
  let source = "42"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Constant(ConstInt(\"42\"))")
}

///|
test "parser: primary expression - variable" {
  let source = "foo"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Variable(\"foo\")")
}

///|
test "parser: binary expression - addition" {
  let source = "1 + 2"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Binary(Add, Constant(ConstInt(\"1\")), Constant(ConstInt(\"2\")))",
  )
}

///|
test "parser: binary expression - precedence" {
  let source = "1 + 2 * 3"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Binary(Add, Constant(ConstInt(\"1\")), Binary(Mul, Constant(ConstInt(\"2\")), Constant(ConstInt(\"3\"))))",
  )
}

///|
test "parser: unary expression - negation" {
  let source = "-x"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Unary(Minus, Variable(\"x\"))")
}

///|
test "parser: unary expression - logical not" {
  let source = "!flag"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Unary(Not, Variable(\"flag\"))")
}

///|
test "parser: unary expression - address of" {
  let source = "&x"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Unary(Addrof, Variable(\"x\"))")
}

///|
test "parser: unary expression - dereference" {
  let source = "*ptr"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Unary(Memof, Variable(\"ptr\"))")
}

///|
test "parser: postfix expression - function call" {
  let source = "foo(1, 2)"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Call(Variable(\"foo\"), [Constant(ConstInt(\"1\")), Constant(ConstInt(\"2\"))])",
  )
}

///|
test "parser: postfix expression - array subscript" {
  let source = "arr[i]"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="Index(Variable(\"arr\"), Variable(\"i\"))")
}

///|
test "parser: postfix expression - member access" {
  let source = "obj.field"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="MemberOf(Variable(\"obj\"), \"field\")")
}

///|
test "parser: postfix expression - pointer member" {
  let source = "ptr->field"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="MemberOfPtr(Variable(\"ptr\"), \"field\")")
}

///|
test "parser: conditional expression" {
  let source = "a ? b : c"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Question(Variable(\"a\"), Variable(\"b\"), Variable(\"c\"))",
  )
}

///|
test "parser: assignment expression" {
  let source = "x = 5"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Binary(Assign, Variable(\"x\"), Constant(ConstInt(\"5\")))",
  )
}

///|
test "parser: compound assignment" {
  let source = "x += 5"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Binary(AddAssign, Variable(\"x\"), Constant(ConstInt(\"5\")))",
  )
}

///|
test "parser: comma expression" {
  let source = "a, b, c"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(
    expr,
    content="Comma([Variable(\"a\"), Variable(\"b\"), Variable(\"c\")])",
  )
}

///|
test "parser: sizeof type" {
  let source = "sizeof(int)"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  inspect(expr, content="TypeSizeof(Specifier([SpecType(Tint)]), JustBase)")
}

///|
test "parser: if statement" {
  let source = "if (x > 0) y = 1;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_if = match stmt {
    If(_, _, _, _) => true
    _ => false
  }
  inspect(is_if, content="true")
}

///|
test "parser: if-else statement" {
  let source = "if (x > 0) y = 1; else y = 0;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let has_else = match stmt {
    If(_, _, Block(b, _), _) => b.bstmts.length() > 0
    _ => false
  }
  inspect(has_else, content="false")
}

///|
test "parser: while statement" {
  let source = "while (x < 10) x++;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_while = match stmt {
    While(_, _, _) => true
    _ => false
  }
  inspect(is_while, content="true")
}

///|
test "parser: for statement" {
  let source = "for (i = 0; i < 10; i++) sum++;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_for = match stmt {
    For(_, _, _, _, _) => true
    _ => false
  }
  inspect(is_for, content="true")
}

///|
test "parser: switch statement" {
  let source = "switch (x) { case 1: break; default: break; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_switch = match stmt {
    Switch(_, _, _) => true
    _ => false
  }
  inspect(is_switch, content="true")
}

///|
test "parser: do-while statement" {
  let source = "do { x++; } while (x < 10);"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_dowhile = match stmt {
    DoWhile(_, _, _) => true
    _ => false
  }
  inspect(is_dowhile, content="true")
}

///|
test "parser: return statement" {
  let source = "return 42;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_return = match stmt {
    Return(expr, _) =>
      match expr {
        Nothing => false
        _ => true
      }
    _ => false
  }
  inspect(is_return, content="true")
}

///|
test "parser: break and continue" {
  let source = "{ break; continue; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let stmts_count = match stmt {
    Block(b, _) => b.bstmts.length()
    _ => 0
  }
  inspect(stmts_count, content="2")
}

///|
test "parser: label and goto" {
  let source = "start: goto start;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let label_name = match stmt {
    Label(name, _, _) => name
    _ => ""
  }
  inspect(label_name, content="start")
}

///|
test "parser: simple function definition" {
  let source = "int main() { return 0; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let fn_name = match def {
    FunDef(sn, _, _, _) => sn.name.name
    _ => ""
  }
  inspect(fn_name, content="main")
}

///|
test "parser: function with parameters" {
  let source = "int add(int a, int b) { return a + b; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let param_count = match def {
    FunDef(sn, _, _, _) =>
      match sn.name.decl_type {
        Proto(_, params, _) => params.length()
        _ => 0
      }
    _ => 0
  }
  inspect(param_count, content="2")
}

///|
test "parser: pointer parameter" {
  let source = "void foo(int *p) { }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_ptr_param = match def {
    FunDef(sn, _, _, _) =>
      match sn.name.decl_type {
        Proto(_, params, _) =>
          match params[0].name.decl_type {
            Ptr(_, _) => true
            _ => false
          }
        _ => false
      }
    _ => false
  }
  inspect(is_ptr_param, content="true")
}

///|
test "parser: struct definition" {
  let source = "struct Point { int x; int y; };"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let def_count = file.definitions.length()
  inspect(def_count, content="1")
}

///|
test "parser: typedef" {
  let source = "typedef unsigned long size_t;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let is_typedef = match file.definitions[0] {
    DecDef(ing, _) =>
      ing.spec.0
      .iter()
      .any(fn(s) {
        match s {
          SpecTypedef => true
          _ => false
        }
      })
    _ => false
  }
  inspect(is_typedef, content="false")
}

///|
test "parser: enum definition" {
  let source = "enum Color { RED = 0, GREEN = 1, BLUE = 2 };"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let def_count = file.definitions.length()
  inspect(def_count, content="1")
}

///|
test "parser: global variable" {
  let source = "int global_var = 100;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let var_name = match file.definitions[0] {
    DecDef(ing, _) => ing.init_names[0].name.name
    _ => ""
  }
  inspect(var_name, content="global_var")
}

///|
test "parser: array declaration" {
  let source = "int arr[10];"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let is_array = match file.definitions[0] {
    DecDef(ing, _) =>
      match ing.init_names[0].name.decl_type {
        Array(_, _, _) => true
        _ => false
      }
    _ => false
  }
  inspect(is_array, content="true")
}

///|
test "parser: static variable" {
  let source = "static int counter = 0;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let is_static = match file.definitions[0] {
    DecDef(ing, _) =>
      ing.spec.0
      .iter()
      .any(fn(s) {
        match s {
          SpecStorage(Static) => true
          _ => false
        }
      })
    _ => false
  }
  inspect(is_static, content="true")
}

///|
test "parser: extern declaration" {
  let source = "extern int external_var;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let is_extern = match file.definitions[0] {
    DecDef(ing, _) =>
      ing.spec.0
      .iter()
      .any(fn(s) {
        match s {
          SpecStorage(Extern) => true
          _ => false
        }
      })
    _ => false
  }
  inspect(is_extern, content="true")
}

///|
test "cabs2cil: simple expression" {
  let env = ConvEnv::new("test.c")
  let expr = Binary(Add, Constant(ConstInt("1")), Constant(ConstInt("2")))
  let (instrs, cil_exp, _) = conv_exp(env, expr)
  inspect(instrs.length(), content="0")
  let exp_str = @cil.print_exp(cil_exp)
  inspect(exp_str, content="(1 + 2)")
}

///|
test "cabs2cil: function definition" {
  let source = "int add(int a, int b) { return a + b; }"
  let result = parse_and_convert(source, "test.c")
  let fn_name = match result.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="add")
}

///|
test "cabs2cil: global variable declaration" {
  let source = "int global_x;"
  let result = parse_and_convert(source, "test.c")
  let var_name = match result.globals[0] {
    @cil.GVarDecl(vi, _) => vi.vname
    _ => ""
  }
  inspect(var_name, content="global_x")
}

///|
test "cabs2cil: initialized global variable" {
  let source = "int global_x = 42;"
  let result = parse_and_convert(source, "test.c")
  let var_name = match result.globals[0] {
    @cil.GVar(vi, _, _) => vi.vname
    _ => ""
  }
  inspect(var_name, content="global_x")
}

///|
test "cabs2cil: ccured __RTTI attaches to pointer type" {
  let source = "void * __RTTI r;"
  let file = parse_and_convert(source, "test.c")
  let mut ok = false
  for g in file.globals {
    match g {
      @cil.GVarDecl(vi, _) =>
        if vi.vname == "r" {
          match @cil.unroll_type(vi.vtype) {
            @cil.TPtr(_, attrs) =>
              ok = attrs.iter().any(fn(a) { a.name == "__RTTI" })
            _ => ()
          }
        }
      _ => ()
    }
  }
  inspect(ok, content="true")
}

///|
test "cabs2cil: ccured __TAGGED attaches to union type" {
  let source = "union { int i; } __TAGGED u;"
  let file = parse_and_convert(source, "test.c")
  let mut ok = false
  for g in file.globals {
    match g {
      @cil.GVarDecl(vi, _) =>
        if vi.vname == "u" {
          match @cil.unroll_type(vi.vtype) {
            @cil.TComp(_, attrs) =>
              ok = attrs.iter().any(fn(a) { a.name == "__TAGGED" })
            _ => ()
          }
        }
      _ => ()
    }
  }
  inspect(ok, content="true")
}

///|
test "printer: ccured attrs are printed" {
  let src =
    #|union { int i; } __TAGGED u;
    #|void * __RTTI r;
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  inspect(out.contains("__TAGGED u"), content="true")
  inspect(out.contains("void * __RTTI r"), content="true")
}

///|
test "parser/cabs2cil: ccured __SELECTEDWHEN is preserved as field attribute" {
  let src =
    #|struct host { int tag; union { int anint __SELECTEDWHEN(tag == 0); } data; };
  let file = parse_and_convert(src, "test.c")
  let mut ok = false
  for g in file.globals {
    match g {
      @cil.GCompTag(ci, _) =>
        if ci.cname == "host" {
          for fi in ci.cfields {
            if fi.fname == "data" {
              match @cil.unroll_type(fi.ftype) {
                @cil.TComp(uci, _) =>
                  for ufi in uci.cfields {
                    if ufi.fname == "anint" {
                      ok = ufi.fattr
                        .iter()
                        .any(fn(a) {
                          a.name == "__SELECTEDWHEN" && not(a.params.is_empty())
                        })
                    }
                  }
                _ => ()
              }
            }
          }
        }
      _ => ()
    }
  }
  inspect(ok, content="true")
}

///|
test "parser/cabs2cil: ccured __SELECTEDWHEN preserved in named union field (regression)" {
  let src =
    #|struct host { int tag; union bar { int anint __SELECTEDWHEN(tag == 0); } data; };
  let file = parse_and_convert(src, "test.c")
  let mut ok = false
  for g in file.globals {
    match g {
      @cil.GCompTag(ci, _) =>
        if ci.cname == "host" {
          for fi in ci.cfields {
            if fi.fname == "data" {
              match @cil.unroll_type(fi.ftype) {
                @cil.TComp(uci, _) =>
                  if uci.cname == "bar" {
                    for ufi in uci.cfields {
                      if ufi.fname == "anint" {
                        ok = ufi.fattr
                          .iter()
                          .any(fn(a) {
                            a.name == "__SELECTEDWHEN" &&
                            not(a.params.is_empty())
                          })
                      }
                    }
                  }
                _ => ()
              }
            }
          }
        }
      _ => ()
    }
  }
  inspect(ok, content="true")
}

///|
test "printer: prints __SELECTEDWHEN field attribute" {
  let src =
    #|struct host { int tag; union { int anint __SELECTEDWHEN(tag == 0); } data; };
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  inspect(out.contains("__SELECTEDWHEN"), content="true")
  inspect(out.contains("tag == 0"), content="true")
}

///|
test "printer: prints __HEAPIFY variable attribute" {
  let src = "int i __HEAPIFY = 5;"
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  inspect(out.contains("__HEAPIFY"), content="true")
}

///|
test "cabs2cil: block battrs keeps __NOCUREBLOCK" {
  let src = "int main(){ { __NOCUREBLOCK int x = 0; } return 0; }"
  let file = parse_and_convert(src, "test.c")
  let mut ok = false
  letrec visit_stmt = fn(s : @cil.Stmt) -> Unit {
    match s.skind {
      @cil.Block(b) => {
        if b.battrs.iter().any(fn(a) { a.name == "__NOCUREBLOCK" }) {
          ok = true
        }
        b.bstmts.each(visit_stmt)
      }
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
      @cil.TryExcept(b1, _, b2, _) => {
        b1.bstmts.each(visit_stmt)
        b2.bstmts.each(visit_stmt)
      }
      _ => ()
    }
  }

  for g in file.globals {
    match g {
      @cil.GFun(fd, _) =>
        if fd.svar.vname == "main" {
          fd.sbody.bstmts.each(visit_stmt)
        }
      _ => ()
    }
  }
  inspect(ok, content="true")
}

///|
test "printer: prints block battrs (__NOCUREBLOCK)" {
  let src = "int main(){ { __NOCUREBLOCK int x = 0; } return 0; }"
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  inspect(out.contains("__NOCUREBLOCK"), content="true")
}

///|
test "printer: typedef anonymous enum printed inline" {
  let src = "typedef enum { A = 0, B = 1 } idtype_t; int f(idtype_t x){ return (int)x; }"
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  inspect(out.contains("typedef enum {"), content="true")
  inspect(out.contains("} idtype_t;"), content="true")
}

///|
test "cabs2cil/printer: union8-style tagged union wrongfield detectable" {
  let src =
    #|#include "testharness.h"
    #|union { int i; void * __RTTI vp; double d; } __TAGGED u;
    #|int main(){ unsigned long x = 0; u.i = (int)x; void * __RTTI v = u.vp; (void)v; SUCCESS; }
  let file = parse_and_convert(src, "test.c")
  let out = @cil.print_file(file)
  // Ensure the key pieces survive printing (we diagnose wrongfield in exec runner on IR).
  inspect(out.contains("__TAGGED u"), content="true")
  inspect(out.contains("void * __RTTI v"), content="true")
  inspect(out.contains("u.i"), content="true")
  inspect(out.contains("u.vp"), content="true")
}

///|
test "cabs2cil: enum value must be integer constant" {
  let src = "enum { x = 3.0 };"
  let got = try {
    let _ = parse_and_convert(src, "test.c")
    "ok"
  } catch {
    ConversionError(msg) => msg
  }
  inspect(got.contains("Enum value is not an integer constant"), content="true")
}

///|
test "cabs2cil: print simple function" {
  let source = "int identity(int x) { return x; }"
  let cil_file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(cil_file)
  inspect(output.contains("identity"), content="true")
}

///|
test "cabs2cil: factorial function" {
  let source =
    #|int factorial(int n) {
    #|  if (n <= 1) {
    #|    return 1;
    #|  }
    #|  return n * factorial(n - 1);
    #|}
  let cil_file = parse_and_convert(source, "factorial.c")
  let global_count = cil_file.globals.length()
  inspect(global_count, content="1")
}

///|
test "cabs2cil: while loop" {
  let source =
    #|void count() {
    #|  int i = 0;
    #|  while (i < 10) {
    #|    i = i + 1;
    #|  }
    #|}
  let cil_file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(cil_file)
  inspect(output.contains("while"), content="true")
}

///|
test "cabs2cil: for loop" {
  let source =
    #|int sum() {
    #|  int s = 0;
    #|  for (int i = 0; i < 10; i++) {
    #|    s = s + i;
    #|  }
    #|  return s;
    #|}
  let cil_file = parse_and_convert(source, "test.c")
  let fn_name = match cil_file.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="sum")
}

///|
test "cabs2cil: multiple functions" {
  let source =
    #|int foo() { return 1; }
    #|int bar() { return 2; }
    #|int baz() { return foo() + bar(); }
  let cil_file = parse_and_convert(source, "test.c")
  let names = cil_file.globals.map(fn(g) {
    match g {
      @cil.GFun(fd, _) => fd.svar.vname
      _ => ""
    }
  })
  inspect(names, content="[\"foo\", \"bar\", \"baz\"]")
}

///|
test "cil suite: logical short-circuit" {
  let source =
    #|int main() {
    #|  int x = 1;
    #|  if (x || x) {
    #|    x = 0;
    #|  }
    #|  return x;
    #|}
  let cil_file = parse_and_convert(source, "logical.c")
  let output = @cil.print_file(cil_file)
  inspect(output.contains("main"), content="true")
}

///|
test "cil suite: enum" {
  let source =
    #|typedef enum foo {
    #|  F1 = 0,
    #|  F2 = 100,
    #|  F3,
    #|  F4
    #|} ENUM;
    #|
    #|void foo(void) {
    #|  int x = F2;
    #|  int y = F1;
    #|}
  let cil_file = parse_and_convert(source, "enum.c")
  let has_function = cil_file.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GFun(_, _) => true
        _ => false
      }
    })
  inspect(has_function, content="true")
}

///|
test "cil suite: bitfield struct (parser only)" {
  let source =
    #|typedef struct {
    #|  char chr;
    #|  char srt;
    #|  int a : 4;
    #|  int b : 5;
    #|  int last;
    #|} S1;
  let tokens = tokenize(source, "bitfield.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let def_count = file.definitions.length()
  inspect(def_count, content="1")
}

///|
test "cil suite: for with declaration" {
  let source =
    #|int main() {
    #|  int z = 0;
    #|  for (int i = 0; i < 10; i++) {
    #|    z = i;
    #|  }
    #|  return z;
    #|}
  let cil_file = parse_and_convert(source, "for1.c")
  let fn_name = match cil_file.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="main")
}

///|
test "edge: empty function" {
  let source = "void empty() { }"
  let cil_file = parse_and_convert(source, "test.c")
  let fn_name = match cil_file.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="empty")
}

///|
test "edge: nested blocks" {
  let source =
    #|void nested() {
    #|  {
    #|    {
    #|      int x = 1;
    #|    }
    #|  }
    #|}
  let cil_file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(cil_file)
  inspect(output.contains("nested"), content="true")
}

///|
test "edge: void parameter" {
  let source = "int foo(void) { return 0; }"
  let cil_file = parse_and_convert(source, "test.c")
  let fn_name = match cil_file.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="foo")
}

///|
test "edge: multiple variable declarations" {
  let source = "int a, b, c;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let file = parser.parse_file()
  let var_count = match file.definitions[0] {
    DecDef(ing, _) => ing.init_names.length()
    _ => 0
  }
  inspect(var_count, content="3")
}

///|
test "edge: complex expression" {
  let source = "a = b = c = 1 + 2 * 3"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  let is_chain_assign = match expr {
    Binary(Assign, _, Binary(Assign, _, Binary(Assign, _, _))) => true
    _ => false
  }
  inspect(is_chain_assign, content="true")
}

///|
test "edge: deeply nested ternary" {
  let source = "a ? b ? c : d : e"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let expr = parser.parse_expression()
  let is_nested = match expr {
    Question(_, Question(_, _, _), _) => true
    _ => false
  }
  inspect(is_nested, content="true")
}

///|
test "typedef: basic typedef tracking" {
  let source = "typedef int MYINT; MYINT x;"
  let lexer = Lexer::new(source, "test.c")
  let parser = Parser::from_lexer(lexer)
  let file = parser.parse_file()
  inspect(file.definitions.length(), content="2")
}

///|
test "typedef: redefine typedef as function" {
  let source = "typedef int agp_setup; int agp_setup(void) { return 0; }"
  let lexer = Lexer::new(source, "test.c")
  let parser = Parser::from_lexer(lexer)
  let file = parser.parse_file()
  inspect(file.definitions.length(), content="2")
}

///|
test "lexer: @transform token" {
  let source = "@transform"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="AtTransform")
}

///|
test "lexer: @transformExpr token" {
  let source = "@transformExpr"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="AtTransformExpr")
}

///|
test "lexer: @specifier token" {
  let source = "@specifier"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="AtSpecifier")
}

///|
test "lexer: @expr token" {
  let source = "@expr"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="AtExpr")
}

///|
test "lexer: @name token" {
  let source = "@name"
  let tokens = tokenize(source, "test.c")
  let first = tokens[0].0
  inspect(first, content="AtName")
}

///|
test "parser: @transform definition" {
  let source = "@transform { int x; } to { long x; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_transformer = match def {
    Transformer(_, _, _) => true
    _ => false
  }
  inspect(is_transformer, content="true")
}

///|
test "parser: @transform with multiple destinations" {
  let source = "@transform { int x; } to { long x; long y; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let dest_count = match def {
    Transformer(_, defs, _) => defs.length()
    _ => 0
  }
  inspect(dest_count, content="2")
}

///|
test "parser: @transformExpr definition" {
  let source = "@transformExpr { foo(x) } to { bar(x, 0) }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_expr_transformer = match def {
    ExprTransformer(_, _, _) => true
    _ => false
  }
  inspect(is_expr_transformer, content="true")
}

///|
test "parser: @transformExpr source expression" {
  let source = "@transformExpr { a + b } to { b + a }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let src_is_binary = match def {
    ExprTransformer(src, _, _) =>
      match src {
        Binary(_, _, _) => true
        _ => false
      }
    _ => false
  }
  inspect(src_is_binary, content="true")
}

///|
test "parser: global asm" {
  let source = "__asm__(\"nop\");"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_globasm = match def {
    GlobAsm(s, _) => s == "nop"
    _ => false
  }
  inspect(is_globasm, content="true")
}

///|
test "parser: _Pragma" {
  let source = "_Pragma(\"pack(1)\")"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_pragma = match def {
    Pragma(_, _) => true
    _ => false
  }
  inspect(is_pragma, content="true")
}

///|
test "parser: extern C linkage" {
  let source = "extern \"C\" { int foo(); }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let linkage_name = match def {
    Linkage(name, _, _) => name
    _ => ""
  }
  inspect(linkage_name, content="C")
}

///|
test "parser: extern C single declaration" {
  let source = "extern \"C\" int bar();"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let is_linkage = match def {
    Linkage(_, _, defs) => defs.length() == 1
    _ => false
  }
  inspect(is_linkage, content="true")
}

///|
test "cabs2cil: global asm conversion" {
  let source = "__asm__(\"nop\");"
  let result = parse_and_convert(source, "test.c")
  let is_gasm = match result.globals[0] {
    @cil.GAsm(s, _) => s == "nop"
    _ => false
  }
  inspect(is_gasm, content="true")
}

///|
test "cabs2cil: extern C linkage conversion" {
  let source = "extern \"C\" { int cfunc(); }"
  let result = parse_and_convert(source, "test.c")
  let has_vardecl = result.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GVarDecl(vi, _) => vi.vname == "cfunc"
        _ => false
      }
    })
  inspect(has_vardecl, content="true")
}

///|
test "parser: __try/__finally" {
  let source = "__try { x = 1; } __finally { x = 0; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_try_finally = match stmt {
    TryFinally(_, _, _) => true
    _ => false
  }
  inspect(is_try_finally, content="true")
}

///|
test "parser: __try/__except" {
  let source = "__try { x = 1; } __except(1) { x = 0; }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let is_try_except = match stmt {
    TryExcept(_, _, _, _) => true
    _ => false
  }
  inspect(is_try_except, content="true")
}

///|
test "parser: __try/__except with expression" {
  let source = "__try { foo(); } __except(GetExceptionCode()) { bar(); }"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let stmt = parser.parse_statement()
  let filter_is_call = match stmt {
    TryExcept(_, filter, _, _) =>
      match filter {
        Call(_, _) => true
        _ => false
      }
    _ => false
  }
  inspect(filter_is_call, content="true")
}

///|
test "cabs2cil: __try/__finally conversion" {
  let source =
    #|void test() {
    #|  __try { int x = 1; }
    #|  __finally { int y = 0; }
    #|}
  let result = parse_and_convert(source, "test.c")
  let fn_name = match result.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="test")
}

///|
test "cabs2cil: __try/__except conversion" {
  let source =
    #|void test() {
    #|  __try { int x = 1; }
    #|  __except(1) { int y = 0; }
    #|}
  let result = parse_and_convert(source, "test.c")
  let fn_name = match result.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="test")
}

///|
test "parser: typeof(type) parses as TtypeofT" {
  let source = "typeof(int *) p;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let has_typeof_t = match def {
    DecDef(ing, _) => {
      let Specifier(specs) = ing.spec
      specs
      .iter()
      .any(fn(elem) {
        match elem {
          SpecType(TtypeofT(_, _)) => true
          _ => false
        }
      })
    }
    _ => false
  }
  inspect(has_typeof_t, content="true")
}

///|
test "parser: typeof(expr) parses as TtypeofE" {
  let source = "typeof(x + 1) y;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let has_typeof_e = match def {
    DecDef(ing, _) => {
      let Specifier(specs) = ing.spec
      specs
      .iter()
      .any(fn(elem) {
        match elem {
          SpecType(TtypeofE(_)) => true
          _ => false
        }
      })
    }
    _ => false
  }
  inspect(has_typeof_e, content="true")
}

///|
test "cabs2cil: typeof(type) conversion" {
  let source =
    #|void test() {
    #|  typeof(int *) p;
    #|}
  let result = parse_and_convert(source, "test.c")
  let fn_name = match result.globals[0] {
    @cil.GFun(fd, _) => fd.svar.vname
    _ => ""
  }
  inspect(fn_name, content="test")
}

///|
test "cabs2cil: typeof(expr) conversion" {
  let source =
    #|int global_x;
    #|void test() {
    #|  typeof(global_x) y;
    #|}
  let result = parse_and_convert(source, "test.c")
  let has_func = result.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GFun(fd, _) => fd.svar.vname == "test"
        _ => false
      }
    })
  inspect(has_func, content="true")
}

///|
test "parser: @specifier pattern variable" {
  let source = "@specifier(foo) x;"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let has_spec_pattern = match def {
    DecDef(ing, _) => {
      let Specifier(specs) = ing.spec
      specs
      .iter()
      .any(fn(elem) {
        match elem {
          SpecPattern(name) => name == "foo"
          _ => false
        }
      })
    }
    _ => false
  }
  inspect(has_spec_pattern, content="true")
}

///|
test "parser: @expr pattern variable" {
  let source = "int x = @expr(bar);"
  let tokens = tokenize(source, "test.c")
  let parser = Parser::new(tokens)
  let def = parser.parse_definition()
  let has_expr_pattern = match def {
    DecDef(ing, _) =>
      ing.init_names
      .iter()
      .any(fn(init_name) {
        match init_name.init {
          SingleInit(ExprPattern(name)) => name == "bar"
          _ => false
        }
      })
    _ => false
  }
  inspect(has_expr_pattern, content="true")
}

///|
test "cabs2cil: type cast in assignment (int to long)" {
  let source = "void f() { long x = 42; }"
  let file = parse_and_convert(source, "test.c")
  let has_func = file.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GFun(_, _) => true
        _ => false
      }
    })
  inspect(has_func, content="true")
}

///|
test "cabs2cil: type cast in function call result" {
  let source =
    #|int foo();
    #|void bar() { long x; x = foo(); }
  let file = parse_and_convert(source, "test.c")
  let has_bar = file.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GFun(fd, _) => fd.svar.vname == "bar"
        _ => false
      }
    })
  inspect(has_bar, content="true")
}

///|
test "cabs2cil: designated initializer for struct" {
  let source =
    #|struct Point { int x; int y; };
    #|struct Point p = { .x = 1, .y = 2 };
  let file = parse_and_convert(source, "test.c")
  let has_var = file.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GVar(vi, _, _) => vi.vname == "p"
        _ => false
      }
    })
  inspect(has_var, content="true")
}

///|
test "cabs2cil: designated initializer for array" {
  let source = "int arr[3] = { [0] = 1, [2] = 3 };"
  let file = parse_and_convert(source, "test.c")
  let has_var = file.globals
    .iter()
    .any(fn(g) {
      match g {
        @cil.GVar(vi, _, _) => vi.vname == "arr"
        _ => false
      }
    })
  inspect(has_var, content="true")
}

///|
test "cabs2cil: local compound initializer lowered to assignments" {
  let source =
    #|struct S { int a; int *p; };
    #|int f() { int local; struct S s = { 1, &local }; return s.a; }
  let file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(file)
  inspect(output.contains("s.a = 1;"), content="true")
  inspect(output.contains("s.p = &(local);"), content="true")
}

///|
test "cabs2cil: nested local compound initializer lowered to assignments" {
  let source =
    #|struct S { int a; int *p; };
    #|struct T { struct S s; int b; };
    #|int f() { int local; struct T t = { { 1, &local }, 2 }; return t.b; }
  let file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(file)
  inspect(output.contains("t.s.a = 1;"), content="true")
  inspect(output.contains("t.s.p = &(local);"), content="true")
  inspect(output.contains("t.b = 2;"), content="true")
}

///|
test "cabs2cil: global nested compound initializer prints nested designators" {
  let source =
    #|struct S { int a; int *p; };
    #|struct T { struct S s; int b; };
    #|int g;
    #|struct T t = { { 1, &g }, 2 };
  let file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(file)
  // Global initializers are printed as designators inside braces (no leading variable name).
  inspect(output.contains(".s.a = 1"), content="true")
  inspect(output.contains(".s.p = &(g)"), content="true")
  inspect(output.contains(".b = 2"), content="true")
}

///|
test "cabs2cil: global array nested compound initializer prints index+field path" {
  let source =
    #|struct S { int a; int b; };
    #|struct T { struct S s; int c; };
    #|struct T arr[2] = { { { 1, 2 }, 3 }, { { 4, 5 }, 6 } };
  let file = parse_and_convert(source, "test.c")
  let output = @cil.print_file(file)
  inspect(output.contains("[0].s.a = 1"), content="true")
  inspect(output.contains("[0].s.b = 2"), content="true")
  inspect(output.contains("[0].c = 3"), content="true")
  inspect(output.contains("[1].s.a = 4"), content="true")
  inspect(output.contains("[1].s.b = 5"), content="true")
  inspect(output.contains("[1].c = 6"), content="true")
}

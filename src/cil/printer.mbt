///|
fn indent(level : Int) -> String {
  let s = StringBuilder::new()
  for i in 0..<level {
    s.write_string("  ")
  } else {
    s.to_string()
  }
}

///|
fn pick_label(labels : Array[Label]) -> String {
  for label in labels {
    match label {
      Label(name, _, _) => return name
      _ => continue
    }
  }
  "__unknown_label"
}

///|
pub fn print_ikind(k : IKind) -> String {
  match k {
    IChar => "char"
    ISChar => "signed char"
    IUChar => "unsigned char"
    IBool => "_Bool"
    IInt => "int"
    IUInt => "unsigned int"
    IShort => "short"
    IUShort => "unsigned short"
    ILong => "long"
    IULong => "unsigned long"
    ILongLong => "long long"
    IULongLong => "unsigned long long"
  }
}

///|
pub fn print_fkind(k : FKind) -> String {
  match k {
    FFloat => "float"
    FDouble => "double"
    FLongDouble => "long double"
  }
}

///|
pub fn print_storage(s : Storage) -> String {
  match s {
    NoStorage => ""
    Static => "static "
    Register => "register "
    Extern => "extern "
  }
}

///|
pub fn print_unop(op : UnOp) -> String {
  match op {
    Neg => "-"
    BNot => "~"
    LNot => "!"
  }
}

///|
pub fn print_binop(op : BinOp) -> String {
  match op {
    PlusA | PlusPI | IndexPI => "+"
    MinusA | MinusPI | MinusPP => "-"
    Mult => "*"
    Div => "/"
    Mod => "%"
    Shiftlt => "<<"
    Shiftrt => ">>"
    Lt => "<"
    Gt => ">"
    Le => "<="
    Ge => ">="
    Eq => "=="
    Ne => "!="
    BAnd => "&"
    BXor => "^"
    BOr => "|"
    LAnd => "&&"
    LOr => "||"
  }
}

///|
pub fn print_constant(c : Constant) -> String {
  match c {
    CInt64(value, _kind, text_opt) =>
      match text_opt {
        Some(text) => text
        None => value.to_string()
      }
    CStr(s) => {
      let escaped = escape_string(s)
      "\"\{escaped}\""
    }
    CWStr(chars) => {
      let mut s = "L\""
      for c in chars {
        s = s + c.to_string()
      } else {
        s + "\""
      }
    }
    CChr(c) => {
      let escaped = match c {
        '\n' => "\\n"
        '\r' => "\\r"
        '\t' => "\\t"
        '\\' => "\\\\"
        '\'' => "\\'"
        '\u{00}' => "\\0"
        _ => String::make(1, c)
      }
      "'\{escaped}'"
    }
    CReal(value, _kind, text_opt) =>
      match text_opt {
        Some(text) => text
        None => value.to_string()
      }
    CEnum(_exp, name, _ei) => name
  }
}

///|
fn escape_char(c : Char) -> String {
  match c {
    '\n' => "\\n"
    '\r' => "\\r"
    '\t' => "\\t"
    '\\' => "\\\\"
    '"' => "\\\""
    _ => c.to_string()
  }
}

///|
fn escape_string(s : String) -> String {
  let mut result = ""
  for c in s {
    result = result + escape_char(c)
  } else {
    result
  }
}

///|
pub fn print_type(t : Typ) -> String {
  print_type_with_name(t, "")
}

///|
fn print_field_type(t : Typ, name : String) -> String {
  match t {
    TArray(base, len_opt, _) => {
      let dims : Array[String] = []
      let len_str = match len_opt {
        Some(e) => print_exp(e)
        None => ""
      }
      dims.push("[\{len_str}]")
      fn collect_dims(typ : Typ) -> Typ {
        match typ {
          TArray(inner, len, _) => {
            let s = match len {
              Some(e) => print_exp(e)
              None => ""
            }
            dims.push("[\{s}]")
            collect_dims(inner)
          }
          _ => typ
        }
      }

      let elem_type = collect_dims(base)
      let dims_str = dims.rev().join("")
      "\{print_type_simple(elem_type)} \{name}\{dims_str}"
    }
    _ => "\{print_type_simple(t)} \{name}"
  }
}

///|
fn print_type_simple(t : Typ) -> String {
  match t {
    TVoid(_) => "void"
    TInt(k, _) => print_ikind(k)
    TFloat(k, _) => print_fkind(k)
    TPtr(base, _) => "\{print_type_simple(base)} *"
    TArray(base, len_opt, _) => {
      let len_str = match len_opt {
        Some(e) => print_exp(e)
        None => ""
      }
      "\{print_type_simple(base)}[\{len_str}]"
    }
    TFun(_, _, _, _) => "void (*)()"
    TNamed(ti, _) => ti.tname
    TComp(ci, _) => {
      let kind = if ci.cstruct { "struct" } else { "union" }
      if ci.cname == "" {
        "\{kind} "
      } else {
        "\{kind} \{ci.cname}"
      }
    }
    TEnum(ei, _) => "enum \{ei.ename}"
    TBuiltinVaList(_) => "__builtin_va_list"
  }
}

///|
pub fn print_type_with_name(t : Typ, name : String) -> String {
  match t {
    TVoid(_) => if name == "" { "void" } else { "void \{name}" }
    TInt(k, _) => {
      let base = print_ikind(k)
      if name == "" {
        base
      } else {
        "\{base} \{name}"
      }
    }
    TFloat(k, _) => {
      let base = print_fkind(k)
      if name == "" {
        base
      } else {
        "\{base} \{name}"
      }
    }
    TPtr(bt, _) => {
      let needs_paren = match bt {
        TArray(_, _, _) | TFun(_, _, _, _) => true
        _ => false
      }
      let name_with_star = if name == "" { "*" } else { "*\{name}" }
      let name_new = if needs_paren {
        "(\{name_with_star})"
      } else {
        name_with_star
      }
      print_type_with_name(bt, name_new)
    }
    TArray(bt, len_opt, _) => {
      let len_str = match len_opt {
        Some(e) => print_exp(e)
        None => ""
      }
      let name_new = "\{name}[\{len_str}]"
      print_type_with_name(bt, name_new)
    }
    TFun(ret, params_opt, vararg, _) => {
      let params_str = match params_opt {
        None => ""
        Some(params) => {
          let parts : Array[String] = params.map(fn(p) {
            let (pname, ptype, _) = p
            print_type_with_name(ptype, pname)
          })
          let base = parts.join(", ")
          if vararg {
            "\{base}, ..."
          } else {
            base
          }
        }
      }
      let name_new = if name == "" {
        "(*)(\{params_str})"
      } else {
        "\{name}(\{params_str})"
      }
      print_type_with_name(ret, name_new)
    }
    TNamed(ti, _) => if name == "" { ti.tname } else { "\{ti.tname} \{name}" }
    TComp(ci, _) => {
      let kind = if ci.cstruct { "struct" } else { "union" }
      if ci.cname == "" && ci.cfields.length() > 0 {
        let fields = ci.cfields.map(fn(fi) {
          let type_name_str = print_field_type(fi.ftype, fi.fname)
          match fi.fbitfield {
            Some(width) => "  \{type_name_str} : \{width};"
            None => "  \{type_name_str};"
          }
        })
        let fields_str = fields.join("\n")
        if name == "" {
          "\{kind} {\n\{fields_str}\n}"
        } else {
          "\{kind} {\n\{fields_str}\n} \{name}"
        }
      } else if name == "" {
        "\{kind} \{ci.cname}"
      } else {
        "\{kind} \{ci.cname} \{name}"
      }
    }
    TEnum(ei, _) =>
      if name == "" {
        "enum \{ei.ename}"
      } else {
        "enum \{ei.ename} \{name}"
      }
    TBuiltinVaList(_) =>
      if name == "" {
        "__builtin_va_list"
      } else {
        "__builtin_va_list \{name}"
      }
  }
}

///|
pub fn print_lval(lv : LVal) -> String {
  let host_str = match lv.host {
    Var(vi) => vi.vname
    Mem(e) => "(*\{print_exp(e)})"
  }
  print_offset(host_str, lv.offset)
}

///|
fn print_offset(base : String, off : Offset) -> String {
  match off {
    NoOffset => base
    Field(fi, rest) => print_offset("\{base}.\{fi.fname}", rest)
    Index(e, rest) => print_offset("\{base}[\{print_exp(e)}]", rest)
  }
}

///|
pub fn print_exp(e : Exp) -> String {
  match e {
    Const(c) => print_constant(c)
    Lval(lv) => print_lval(lv)
    SizeOf(t) => "sizeof(\{print_type(t)})"
    SizeOfE(exp) => "sizeof(\{print_exp(exp)})"
    SizeOfStr(s) => {
      let escaped = escape_string(s)
      "sizeof(\"\{escaped}\")"
    }
    AlignOf(t) => "__alignof__(\{print_type(t)})"
    AlignOfE(exp) => "__alignof__(\{print_exp(exp)})"
    UnOp(op, exp, _) => "\{print_unop(op)}\{print_exp(exp)}"
    BinOp(op, e1, e2, _) =>
      "(\{print_exp(e1)} \{print_binop(op)} \{print_exp(e2)})"
    Question(cond, e1, e2, _) =>
      "(\{print_exp(cond)} ? \{print_exp(e1)} : \{print_exp(e2)})"
    CastE(t, exp) => "((\{print_type(t)})\{print_exp(exp)})"
    AddrOf(lv) => "&(\{print_lval(lv)})"
    AddrOfLabel(s) => "&&label_\{s.sid}"
    StartOf(lv) => print_lval(lv)
  }
}

///|
pub fn print_instr(i : Instr, level : Int) -> String {
  let ind = indent(level)
  match i {
    Set(lv, exp, _) => "\{ind}\{print_lval(lv)} = \{print_exp(exp)};"
    Call(lv_opt, func, args, _) => {
      let lv_str = match lv_opt {
        Some(lv) => "\{print_lval(lv)} = "
        None => ""
      }
      let args_str = args.map(print_exp).join(", ")
      "\{ind}\{lv_str}\{print_exp(func)}(\{args_str});"
    }
    Asm(_, templates, outputs, inputs, clobbers, _) => {
      let sep = "\\n"
      let template_str = templates.map(fn(t) { "\"\{t}\"" }).join(sep)
      let outputs_str = outputs
        .map(fn(o) {
          let (_, constraint, lv) = o
          "\"\{constraint}\" (\{print_lval(lv)})"
        })
        .join(", ")
      let inputs_str = inputs
        .map(fn(inp) {
          let (_, constraint, exp) = inp
          "\"\{constraint}\" (\{print_exp(exp)})"
        })
        .join(", ")
      let clobbers_str = clobbers.map(fn(c) { "\"\{c}\"" }).join(", ")
      "\{ind}__asm__ (\{template_str} : \{outputs_str} : \{inputs_str} : \{clobbers_str});"
    }
  }
}

///|
fn print_label(l : Label) -> String {
  match l {
    Label(name, _, _) => "\{name}:"
    Case(exp, _) => "case \{print_exp(exp)}:"
    CaseRange(e1, e2, _) => "case \{print_exp(e1)} ... \{print_exp(e2)}:"
    Default(_) => "default:"
  }
}

///|
pub fn print_stmt(s : Stmt, level : Int) -> String {
  let ind = indent(level)
  let labels_str = s.labels.map(print_label).join("\n")
  let labels_prefix = if labels_str == "" { "" } else { labels_str + "\n" }
  let body_str = match s.skind {
    Instr(instrs) => instrs.map(fn(i) { print_instr(i, level) }).join("\n")
    Return(exp_opt, _) =>
      match exp_opt {
        Some(e) => "\{ind}return \{print_exp(e)};"
        None => "\{ind}return;"
      }
    Goto(target, _) => {
      let label_name = pick_label(target.labels)
      "\{ind}goto \{label_name};"
    }
    ComputedGoto(exp, _) => "\{ind}goto *\{print_exp(exp)};"
    Break(_) => "\{ind}break;"
    Continue(_) => "\{ind}continue;"
    If(cond, then_block, else_block, _) => {
      let then_str = print_block_inline(then_block, level)
      let else_part = if else_block.bstmts.is_empty() {
        ""
      } else {
        let else_body = print_block_inline(else_block, level)
        " else \{else_body}"
      }
      "\{ind}if (\{print_exp(cond)}) \{then_str}\{else_part}"
    }
    Switch(exp, block, _, _) =>
      "\{ind}switch (\{print_exp(exp)}) \{print_block_inline(block, level)}"
    Loop(block, _, _, _) =>
      "\{ind}while (1) \{print_block_inline(block, level)}"
    Block(block) => print_block(block, level)
    TryFinally(try_block, finally_block, _) => {
      let try_str = print_block_inline(try_block, level)
      let finally_str = print_block_inline(finally_block, level)
      "\{ind}__try \{try_str} __finally \{finally_str}"
    }
    TryExcept(try_block, (_, exp), except_block, _) => {
      let try_str = print_block_inline(try_block, level)
      let except_str = print_block_inline(except_block, level)
      "\{ind}__try \{try_str} __except(\{print_exp(exp)}) \{except_str}"
    }
  }
  labels_prefix + body_str
}

///|
pub fn print_block(block : Block, level : Int) -> String {
  let ind = indent(level)
  let stmts_str = block.bstmts
    .map(fn(s) { print_stmt(s, level + 1) })
    .filter(fn(s) { not(s.is_empty()) })
    .join("\n")
  "\{ind}{\n\{stmts_str}\n\{ind}}"
}

///|
fn print_block_inline(block : Block, level : Int) -> String {
  let ind = indent(level)
  let stmts_str = block.bstmts
    .map(fn(s) { print_stmt(s, level + 1) })
    .filter(fn(s) { not(s.is_empty()) })
    .join("\n")
  "{\n\{stmts_str}\n\{ind}}"
}

///|
pub fn print_fundec(fd : FunDec) -> String {
  let storage = print_storage(fd.svar.vstorage)
  let ret_type = match fd.svar.vtype {
    TFun(ret, _, _, _) => print_type(ret)
    _ => "int"
  }
  let params_str = fd.sformals
    .map(fn(vi) { print_type_with_name(vi.vtype, vi.vname) })
    .join(", ")
  let locals_lines = fd.slocals.map(fn(vi) {
    "  \{print_type_with_name(vi.vtype, vi.vname)};"
  })
  let locals_str = locals_lines.join("\n")
  let body_stmts = fd.sbody.bstmts
    .map(fn(s) { print_stmt(s, 1) })
    .filter(fn(s) { not(s.is_empty()) })
    .join("\n")
  let locals_section = if locals_lines.is_empty() {
    ""
  } else {
    locals_str + "\n"
  }
  "\{storage}\{ret_type} \{fd.svar.vname}(\{params_str})\n{\n\{locals_section}\{body_stmts}\n}"
}

///|
fn print_compinfo(ci : CompInfo) -> String {
  let kind = if ci.cstruct { "struct" } else { "union" }
  let fields = ci.cfields.map(fn(fi) {
    match fi.fbitfield {
      Some(width) => "  \{print_type_with_name(fi.ftype, fi.fname)} : \{width};"
      None => "  \{print_type_with_name(fi.ftype, fi.fname)};"
    }
  })
  let newline = "\n"
  let fields_str = fields.join(newline)
  "\{kind} \{ci.cname} {\n\{fields_str}\n}"
}

///|
fn print_enuminfo(ei : EnumInfo) -> String {
  let items = ei.eitems.map(fn(item) {
    let (name, exp, _) = item
    "  \{name} = \{print_exp(exp)}"
  })
  let newline = ",\n"
  let items_str = items.join(newline)
  "enum \{ei.ename} {\n\{items_str}\n}"
}

///|
pub fn print_init(init : Init) -> String {
  match init {
    SingleInit(e) => print_exp(e)
    CompoundInit(_, inits) => {
      let parts = inits
        .map(fn(item) {
          let (off, i) = item
          let off_str = print_init_offset(off)
          "\{off_str}\{print_init(i)}"
        })
        .join(", ")
      "{\{parts}}"
    }
  }
}

///|
fn print_init_offset(off : Offset) -> String {
  match off {
    NoOffset => ""
    Field(fi, NoOffset) => ".\{fi.fname} = "
    Index(e, NoOffset) => "[\{print_exp(e)}] = "
    _ => ""
  }
}

///|
pub fn print_global(g : Global) -> String {
  match g {
    GType(ti, _) => "typedef \{print_type_with_name(ti.ttype, ti.tname)};"
    GCompTag(ci, _) => "\{print_compinfo(ci)};"
    GCompTagDecl(ci, _) => {
      let kind = if ci.cstruct { "struct" } else { "union" }
      "\{kind} \{ci.cname};"
    }
    GEnumTag(ei, _) => "\{print_enuminfo(ei)};"
    GEnumTagDecl(ei, _) => "enum \{ei.ename};"
    GVarDecl(vi, _) => {
      let storage = print_storage(vi.vstorage)
      "\{storage}\{print_type_with_name(vi.vtype, vi.vname)};"
    }
    GVar(vi, ii, _) => {
      let storage = print_storage(vi.vstorage)
      let init_str = match ii.init {
        Some(init) => " = \{print_init(init)}"
        None => ""
      }
      "\{storage}\{print_type_with_name(vi.vtype, vi.vname)}\{init_str};"
    }
    GFun(fd, _) => print_fundec(fd)
    GAsm(s, _) => {
      let escaped = escape_string(s)
      "__asm__(\"\{escaped}\");"
    }
    GPragma(attr, _) => "#pragma \{attr.name}"
    GText(s) => s
  }
}

///|
pub fn print_file(file : File) -> String {
  let header = ""
  let globals_str = file.globals.map(print_global).join("\n\n")
  "\{header}\n\n\{globals_str}\n"
}

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
fn print_cv(attrs : Array[Attribute]) -> String {
  let mut has_const = false
  let mut has_volatile = false
  let mut has_restrict = false
  for a in attrs {
    if a.params.is_empty() {
      if a.name == "const" {
        has_const = true
      } else if a.name == "volatile" {
        has_volatile = true
      } else if a.name == "restrict" {
        has_restrict = true
      }
    }
  }
  let parts : Array[String] = []
  if has_const {
    parts.push("const")
  }
  if has_volatile {
    parts.push("volatile")
  }
  if has_restrict {
    parts.push("restrict")
  }
  if parts.is_empty() {
    ""
  } else {
    parts.join(" ") + " "
  }
}

///|
fn print_noncv_simple_attrs(attrs : Array[Attribute]) -> Array[String] {
  let parts : Array[String] = []
  for a in attrs {
    if a.params.is_empty() &&
      a.name != "const" &&
      a.name != "volatile" &&
      a.name != "restrict" {
      parts.push(a.name)
    }
  }
  parts
}

///|
fn print_attrparam(p : AttrParam) -> String {
  match p {
    AInt(n) => n.to_string()
    AStr(s) => "\"\{escape_string(s)}\""
    ACons(name, args) =>
      if args.is_empty() {
        name
      } else {
        let args_str = args.map(print_attrparam).join(", ")
        "\{name}(\{args_str})"
      }
    ASizeOf(t) => "sizeof(\{print_type(t)})"
    ASizeOfE(e) => "sizeof(\{print_attrparam(e)})"
    AAlignOf(t) => "__alignof__(\{print_type(t)})"
    AAlignOfE(e) => "__alignof__(\{print_attrparam(e)})"
    AUnOp(op, a) => "\{print_unop(op)}(\{print_attrparam(a)})"
    ABinOp(op, a, b) =>
      "(\{print_attrparam(a)} \{print_binop(op)} \{print_attrparam(b)})"
    ADot(a, f) => "\{print_attrparam(a)}.\{f}"
    AStar(a) => "*\{print_attrparam(a)}"
    AAddrOf(a) => "&\{print_attrparam(a)}"
    AIndex(a, i) => "\{print_attrparam(a)}[\{print_attrparam(i)}]"
    AQuestion(a, b, c) =>
      "(\{print_attrparam(a)} ? \{print_attrparam(b)} : \{print_attrparam(c)})"
  }
}

///|
fn print_attrs_after_name(attrs : Array[Attribute]) -> String {
  let parts : Array[String] = []
  for a in attrs {
    if a.name == "const" || a.name == "volatile" || a.name == "restrict" {
      continue
    }
    if a.params.is_empty() {
      parts.push(a.name)
    } else {
      let ps = a.params.map(print_attrparam).join(", ")
      parts.push("\{a.name}(\{ps})")
    }
  }
  if parts.is_empty() {
    ""
  } else {
    " " + parts.join(" ")
  }
}

///|
fn print_block_attrs(attrs : Array[Attribute]) -> String {
  let parts : Array[String] = []
  for a in attrs {
    if a.params.is_empty() {
      parts.push(a.name)
    } else {
      let ps = a.params.map(print_attrparam).join(", ")
      parts.push("\{a.name}(\{ps})")
    }
  }
  parts.join(" ")
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
      match elem_type {
        TComp(ci, _) if ci.cname == "" && ci.cfields.length() > 0 =>
          print_type_with_name(elem_type, "\{name}\{dims_str}")
        _ => "\{print_type_simple(elem_type)} \{name}\{dims_str}"
      }
    }
    TComp(ci, _) if ci.cname == "" && ci.cfields.length() > 0 =>
      print_type_with_name(t, name)
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
    TEnum(ei, _) =>
      if ei.ename != "" {
        "enum \{ei.ename}"
      } else if ei.eitems.length() > 0 {
        let items = ei.eitems.map(fn(item) {
          let (n, e, _) = item
          "\{n} = \{print_exp(e)}"
        })
        let items_str = items.join(", ")
        "enum {\{items_str}}"
      } else {
        "enum"
      }
    TBuiltinVaList(_) => "__builtin_va_list"
  }
}

///|
pub fn print_type_with_name(t : Typ, name : String) -> String {
  match t {
    TVoid(a) => {
      let cv = print_cv(a)
      if name == "" {
        "\{cv}void"
      } else {
        "\{cv}void \{name}"
      }
    }
    TInt(k, a) => {
      let base = print_ikind(k)
      let cv = print_cv(a)
      if name == "" {
        "\{cv}\{base}"
      } else {
        "\{cv}\{base} \{name}"
      }
    }
    TFloat(k, a) => {
      let base = print_fkind(k)
      let cv = print_cv(a)
      if name == "" {
        "\{cv}\{base}"
      } else {
        "\{cv}\{base} \{name}"
      }
    }
    TPtr(bt, a) => {
      let needs_paren = match bt {
        TArray(_, _, _) | TFun(_, _, _, _) => true
        _ => false
      }
      let cv = print_cv(a).trim().to_string()
      let extra = print_noncv_simple_attrs(a).join(" ")
      let mods = "\{cv} \{extra}".trim().to_string()
      let star = if mods == "" { "*" } else { "* \{mods}" }
      let name_with_star = if name == "" {
        star
      } else if mods == "" {
        "\{star}\{name}"
      } else {
        "\{star} \{name}"
      }
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
    TNamed(ti, a) => {
      let cv = print_cv(a)
      if name == "" {
        "\{cv}\{ti.tname}"
      } else {
        "\{cv}\{ti.tname} \{name}"
      }
    }
    TComp(ci, a) => {
      let kind = if ci.cstruct { "struct" } else { "union" }
      let cv = print_cv(a)
      let extra = print_noncv_simple_attrs(a)
      if ci.cname == "" && ci.cfields.length() > 0 {
        let fields = ci.cfields.map(fn(fi) {
          let type_name_str = print_field_type(
            fi.ftype,
            fi.fname + print_attrs_after_name(fi.fattr),
          )
          match fi.fbitfield {
            Some(width) => "  \{type_name_str} : \{width};"
            None => "  \{type_name_str};"
          }
        })
        let fields_str = fields.join("\n")
        let base = "\{cv}\{kind} {\n\{fields_str}\n}"
        let tail_parts : Array[String] = []
        if not(extra.is_empty()) {
          tail_parts.push(extra.join(" "))
        }
        if name != "" {
          tail_parts.push(name)
        }
        if tail_parts.is_empty() {
          base
        } else {
          let tail = tail_parts.join(" ")
          "\{base} \{tail}"
        }
      } else if name == "" {
        let base = "\{cv}\{kind} \{ci.cname}"
        if extra.is_empty() {
          base
        } else {
          let tail = extra.join(" ")
          "\{base} \{tail}"
        }
      } else {
        let base = "\{cv}\{kind} \{ci.cname}"
        let tail_parts : Array[String] = []
        if not(extra.is_empty()) {
          tail_parts.push(extra.join(" "))
        }
        tail_parts.push(name)
        let tail = tail_parts.join(" ")
        "\{base} \{tail}"
      }
    }
    TEnum(ei, a) =>
      if ei.ename != "" {
        if name == "" {
          "\{print_cv(a)}enum \{ei.ename}"
        } else {
          "\{print_cv(a)}enum \{ei.ename} \{name}"
        }
      } else if ei.eitems.length() > 0 {
        let items = ei.eitems.map(fn(item) {
          let (n, e, _) = item
          "  \{n} = \{print_exp(e)}"
        })
        let items_str = items.join(",\n")
        let enum_str = "\{print_cv(a)}enum {\n\{items_str}\n}"
        if name == "" {
          enum_str
        } else {
          "\{enum_str} \{name}"
        }
      } else if name == "" {
        "\{print_cv(a)}enum"
      } else {
        "\{print_cv(a)}enum \{name}"
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
  let ind2 = indent(level + 1)
  let attrs_line = print_block_attrs(block.battrs)
  let attrs_section = if attrs_line == "" {
    ""
  } else {
    "\{ind2}\{attrs_line}\n"
  }
  let stmts_str = block.bstmts
    .map(fn(s) { print_stmt(s, level + 1) })
    .filter(fn(s) { not(s.is_empty()) })
    .join("\n")
  "\{ind}{\n\{attrs_section}\{stmts_str}\n\{ind}}"
}

///|
fn print_block_inline(block : Block, level : Int) -> String {
  let ind = indent(level)
  let ind2 = indent(level + 1)
  let attrs_line = print_block_attrs(block.battrs)
  let attrs_section = if attrs_line == "" {
    ""
  } else {
    "\{ind2}\{attrs_line}\n"
  }
  let stmts_str = block.bstmts
    .map(fn(s) { print_stmt(s, level + 1) })
    .filter(fn(s) { not(s.is_empty()) })
    .join("\n")
  "{\n\{attrs_section}\{stmts_str}\n\{ind}}"
}

///|
pub fn print_fundec(fd : FunDec) -> String {
  let storage = print_storage(fd.svar.vstorage)
  let ret_type = match fd.svar.vtype {
    TFun(ret, _, _, _) => print_type(ret)
    _ => "int"
  }
  let params_str = fd.sformals
    .map(fn(vi) {
      print_type_with_name(
        vi.vtype,
        vi.vname + print_attrs_after_name(vi.vattr),
      )
    })
    .join(", ")
  let locals_lines = fd.slocals.map(fn(vi) {
    "  \{print_type_with_name(vi.vtype, vi.vname + print_attrs_after_name(vi.vattr))};"
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
      Some(width) =>
        "  \{print_type_with_name(fi.ftype, fi.fname + print_attrs_after_name(fi.fattr))} : \{width};"
      None =>
        "  \{print_type_with_name(fi.ftype, fi.fname + print_attrs_after_name(fi.fattr))};"
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
  fn print_init_offset_path(off : Offset) -> String {
    match off {
      NoOffset => ""
      Field(fi, rest) => ".\{fi.fname}\{print_init_offset_path(rest)}"
      Index(e, rest) => "[\{print_exp(e)}]\{print_init_offset_path(rest)}"
    }
  }

  let path = print_init_offset_path(off)
  if path == "" {
    ""
  } else {
    "\{path} = "
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
      "\{storage}\{print_type_with_name(vi.vtype, vi.vname + print_attrs_after_name(vi.vattr))};"
    }
    GVar(vi, ii, _) => {
      let storage = print_storage(vi.vstorage)
      let init_str = match ii.init {
        Some(init) => " = \{print_init(init)}"
        None => ""
      }
      "\{storage}\{print_type_with_name(vi.vtype, vi.vname + print_attrs_after_name(vi.vattr))}\{init_str};"
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

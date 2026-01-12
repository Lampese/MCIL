///|
fn parse_int64(s : String) -> Int64 {
  let mut result = 0L
  let mut neg = false
  let mut i = 0
  if s.length() > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X') {
    i = 2
    while i < s.length() {
      let c = s[i]
      let digit = if c >= '0' && c <= '9' {
        c.to_int() - '0'.to_int()
      } else if c >= 'a' && c <= 'f' {
        c.to_int() - 'a'.to_int() + 10
      } else if c >= 'A' && c <= 'F' {
        c.to_int() - 'A'.to_int() + 10
      } else {
        break
      }
      result = result * 16L + digit.to_int64()
      i = i + 1
    }
  } else {
    if s.length() > 0 && s[0] == '-' {
      neg = true
      i = 1
    }
    while i < s.length() {
      let c = s[i]
      if c >= '0' && c <= '9' {
        result = result * 10L + (c.to_int() - '0'.to_int()).to_int64()
        i = i + 1
      } else {
        break
      }
    }
  }
  if neg {
    -result
  } else {
    result
  }
}

///|
fn parse_double(s : String) -> Double {
  let mut result = 0.0
  let mut i = 0
  let mut neg = false
  if s.length() > 0 && s[0] == '-' {
    neg = true
    i = 1
  }
  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - '0'.to_int()).to_double()
      i = i + 1
    } else {
      break
    }
  }
  if i < s.length() && s[i] == '.' {
    i = i + 1
    let mut frac = 0.1
    while i < s.length() {
      let c = s[i]
      if c >= '0' && c <= '9' {
        result = result + (c.to_int() - '0'.to_int()).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  if neg {
    -result
  } else {
    result
  }
}

///|
pub suberror ConversionError {
  ConversionError(String)
}

///|
pub enum EnvEntry {
  EnvVar(@cil.VarInfo)
  EnvTypeDef(@cil.TypeInfo)
  EnvEnum(@cil.Exp, @cil.Typ)
}

///|
struct GotoInfo {
  label_name : String
  goto_stmt : @cil.Stmt
}

///|
pub struct ConvEnv {
  env : Map[String, EnvEntry]
  genv : Map[String, EnvEntry]
  current_fun : @cil.FunDec?
  locals : Array[@cil.VarInfo]
  mut temp_counter : Int
  filename : String
  labels : Map[String, @cil.Stmt]
  gotos : Array[GotoInfo]
  comps : Map[String, @cil.CompInfo]
  emitted_comps : Map[Int, Bool]
  emitted_enums : Map[String, Bool]
  emitted_vars : Map[String, Bool]
}

///|
pub fn ConvEnv::new(filename : String) -> ConvEnv {
  let env = {}
  let genv = {}
  let va_list_ti : @cil.TypeInfo = {
    tname: "__builtin_va_list",
    ttype: @cil.TBuiltinVaList([]),
    treferenced: true,
  }
  genv["__builtin_va_list"] = EnvTypeDef(va_list_ti)
  let size_t_ti : @cil.TypeInfo = {
    tname: "size_t",
    ttype: @cil.TInt(@cil.IULong, []),
    treferenced: true,
  }
  genv["size_t"] = EnvTypeDef(size_t_ti)
  let ptrdiff_t_ti : @cil.TypeInfo = {
    tname: "ptrdiff_t",
    ttype: @cil.TInt(@cil.ILong, []),
    treferenced: true,
  }
  genv["ptrdiff_t"] = EnvTypeDef(ptrdiff_t_ti)
  let intptr_t_ti : @cil.TypeInfo = {
    tname: "intptr_t",
    ttype: @cil.TInt(@cil.ILong, []),
    treferenced: true,
  }
  genv["intptr_t"] = EnvTypeDef(intptr_t_ti)
  let uintptr_t_ti : @cil.TypeInfo = {
    tname: "uintptr_t",
    ttype: @cil.TInt(@cil.IULong, []),
    treferenced: true,
  }
  genv["uintptr_t"] = EnvTypeDef(uintptr_t_ti)
  let wchar_t_ti : @cil.TypeInfo = {
    tname: "wchar_t",
    ttype: @cil.TInt(@cil.IInt, []),
    treferenced: true,
  }
  genv["wchar_t"] = EnvTypeDef(wchar_t_ti)
  let system_types = [
    ("__mbstate_t", @cil.TInt(@cil.IInt, [])),
    ("__quad_t", @cil.TInt(@cil.ILongLong, [])),
    ("__u_quad_t", @cil.TInt(@cil.IULongLong, [])),
    ("__int64_t", @cil.TInt(@cil.ILongLong, [])),
    ("__uint64_t", @cil.TInt(@cil.IULongLong, [])),
    ("__int32_t", @cil.TInt(@cil.IInt, [])),
    ("__uint32_t", @cil.TInt(@cil.IUInt, [])),
    ("__int16_t", @cil.TInt(@cil.IShort, [])),
    ("__uint16_t", @cil.TInt(@cil.IUShort, [])),
    ("__int8_t", @cil.TInt(@cil.ISChar, [])),
    ("__uint8_t", @cil.TInt(@cil.IUChar, [])),
    ("__intptr_t", @cil.TInt(@cil.ILong, [])),
    ("__uintptr_t", @cil.TInt(@cil.IULong, [])),
    ("__time_t", @cil.TInt(@cil.ILong, [])),
    ("__clock_t", @cil.TInt(@cil.ILong, [])),
    ("__pid_t", @cil.TInt(@cil.IInt, [])),
    ("__uid_t", @cil.TInt(@cil.IUInt, [])),
    ("__gid_t", @cil.TInt(@cil.IUInt, [])),
    ("__off_t", @cil.TInt(@cil.ILong, [])),
    ("__off64_t", @cil.TInt(@cil.ILongLong, [])),
    ("__ssize_t", @cil.TInt(@cil.ILong, [])),
    ("__kernel_size_t", @cil.TInt(@cil.IULong, [])),
    ("__kernel_fd_set", @cil.TInt(@cil.IInt, [])),
    ("__sighandler_t", @cil.TPtr(@cil.TVoid([]), [])),
    ("atomic_t", @cil.TInt(@cil.IInt, [])),
    ("spinlock_t", @cil.TInt(@cil.IInt, [])),
    ("rwlock_t", @cil.TInt(@cil.IInt, [])),
    ("int8_t", @cil.TInt(@cil.ISChar, [])),
    ("int16_t", @cil.TInt(@cil.IShort, [])),
    ("int32_t", @cil.TInt(@cil.IInt, [])),
    ("int64_t", @cil.TInt(@cil.ILongLong, [])),
    ("uint8_t", @cil.TInt(@cil.IUChar, [])),
    ("uint16_t", @cil.TInt(@cil.IUShort, [])),
    ("uint32_t", @cil.TInt(@cil.IUInt, [])),
    ("uint64_t", @cil.TInt(@cil.IULongLong, [])),
    ("ssize_t", @cil.TInt(@cil.ILong, [])),
    ("off_t", @cil.TInt(@cil.ILong, [])),
    ("time_t", @cil.TInt(@cil.ILong, [])),
    ("clock_t", @cil.TInt(@cil.ILong, [])),
    ("pid_t", @cil.TInt(@cil.IInt, [])),
    ("uid_t", @cil.TInt(@cil.IUInt, [])),
    ("gid_t", @cil.TInt(@cil.IUInt, [])),
    ("FILE", @cil.TInt(@cil.IInt, [])),
    ("va_list", @cil.TBuiltinVaList([])),
    ("jmp_buf", @cil.TInt(@cil.IInt, [])),
    ("boolean", @cil.TInt(@cil.IInt, [])),
    ("BOOL", @cil.TInt(@cil.IInt, [])),
    ("GUID", @cil.TInt(@cil.IInt, [])),
    ("__darwin_wchar_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_size_t", @cil.TInt(@cil.IULong, [])),
    ("__darwin_ptrdiff_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_intptr_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_ino64_t", @cil.TInt(@cil.IULongLong, [])),
    ("__darwin_ino_t", @cil.TInt(@cil.IULongLong, [])),
    ("__darwin_off_t", @cil.TInt(@cil.ILongLong, [])),
    ("__darwin_time_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_clock_t", @cil.TInt(@cil.IULong, [])),
    ("__darwin_pid_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_uid_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_gid_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_mode_t", @cil.TInt(@cil.IUShort, [])),
    ("__darwin_dev_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_socklen_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_ssize_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_natural_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_mach_port_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_mach_port_name_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_blkcnt_t", @cil.TInt(@cil.ILongLong, [])),
    ("__darwin_blksize_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_fsblkcnt_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_fsfilcnt_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_useconds_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_suseconds_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_nl_item", @cil.TInt(@cil.IInt, [])),
    ("__darwin_wint_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_wctype_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_va_list", @cil.TBuiltinVaList([])),
    ("__gnuc_va_list", @cil.TBuiltinVaList([])),
    ("errno_t", @cil.TInt(@cil.IInt, [])),
    ("rsize_t", @cil.TInt(@cil.IULong, [])),
    ("quad_t", @cil.TInt(@cil.ILongLong, [])),
    ("u_quad_t", @cil.TInt(@cil.IULongLong, [])),
    ("fpos_t", @cil.TInt(@cil.ILongLong, [])),
    ("sigjmp_buf", @cil.TInt(@cil.IInt, [])),
    ("sig_atomic_t", @cil.TInt(@cil.IInt, [])),
    ("__darwin_id_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_ct_rune_t", @cil.TInt(@cil.IInt, [])),
    ("__u_int", @cil.TInt(@cil.IUInt, [])),
    ("__locale_t", @cil.TPtr(@cil.TVoid([]), [])),
    ("__kernel_dev_t", @cil.TInt(@cil.IUInt, [])),
    ("__CONST_SOCKADDR_ARG", @cil.TPtr(@cil.TVoid([]), [])),
    ("NTSTATUS", @cil.TInt(@cil.ILong, [])),
    ("mode_t", @cil.TInt(@cil.IUShort, [])),
    ("useconds_t", @cil.TInt(@cil.IUInt, [])),
    ("suseconds_t", @cil.TInt(@cil.IInt, [])),
    ("blkcnt_t", @cil.TInt(@cil.ILongLong, [])),
    ("blksize_t", @cil.TInt(@cil.IInt, [])),
    ("ino_t", @cil.TInt(@cil.IULongLong, [])),
    ("dev_t", @cil.TInt(@cil.IInt, [])),
    ("nlink_t", @cil.TInt(@cil.IUShort, [])),
    ("socklen_t", @cil.TInt(@cil.IUInt, [])),
    ("__darwin_pthread_attr_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_pthread_mutex_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_pthread_cond_t", @cil.TInt(@cil.ILong, [])),
    ("__darwin_pthread_t", @cil.TPtr(@cil.TVoid([]), [])),
    ("pthread_t", @cil.TPtr(@cil.TVoid([]), [])),
    ("pthread_attr_t", @cil.TInt(@cil.ILong, [])),
    ("pthread_mutex_t", @cil.TInt(@cil.ILong, [])),
    ("pthread_cond_t", @cil.TInt(@cil.ILong, [])),
    ("u_int8_t", @cil.TInt(@cil.IUChar, [])),
    ("u_int16_t", @cil.TInt(@cil.IUShort, [])),
    ("u_int32_t", @cil.TInt(@cil.IUInt, [])),
    ("u_int64_t", @cil.TInt(@cil.IULongLong, [])),
    ("__kernel_uid32_t", @cil.TInt(@cil.IUInt, [])),
    ("__kernel_gid32_t", @cil.TInt(@cil.IUInt, [])),
    ("__u8", @cil.TInt(@cil.IUChar, [])),
    ("__u16", @cil.TInt(@cil.IUShort, [])),
    ("__u32", @cil.TInt(@cil.IUInt, [])),
    ("__u64", @cil.TInt(@cil.IULongLong, [])),
    ("__s8", @cil.TInt(@cil.ISChar, [])),
    ("__s16", @cil.TInt(@cil.IShort, [])),
    ("__s32", @cil.TInt(@cil.IInt, [])),
    ("__s64", @cil.TInt(@cil.ILongLong, [])),
  ]
  for item in system_types {
    let (name, typ) = item
    let ti = @cil.TypeInfo::{ tname: name, ttype: typ, treferenced: true }
    genv[name] = EnvTypeDef(ti)
  }
  {
    env,
    genv,
    current_fun: None,
    locals: [],
    temp_counter: 0,
    filename,
    labels: {},
    gotos: [],
    comps: {},
    emitted_comps: {},
    emitted_enums: {},
    emitted_vars: {},
  }
}

///|
fn resolve_gotos(env : ConvEnv) -> Unit {
  for goto_info in env.gotos {
    match env.labels.get(goto_info.label_name) {
      Some(target_stmt) =>
        match goto_info.goto_stmt.skind {
          Goto(_, loc) =>
            goto_info.goto_stmt.skind = @cil.Goto(target_stmt, loc)
          _ => ()
        }
      None => ()
    }
  }
}

///|
fn find_field(
  field_name : String,
  fields : Array[@cil.FieldInfo],
) -> @cil.FieldInfo? {
  for fi in fields {
    if fi.fname == field_name {
      return Some(fi)
    }
  }
  None
}

///|
fn add_offset(base : @cil.Offset, new_off : @cil.Offset) -> @cil.Offset {
  match base {
    NoOffset => new_off
    Field(fi, rest) => @cil.Field(fi, add_offset(rest, new_off))
    Index(exp, rest) => @cil.Index(exp, add_offset(rest, new_off))
  }
}

///|
fn unroll_type(t : @cil.Typ) -> @cil.Typ {
  match t {
    TNamed(ti, _) => unroll_type(ti.ttype)
    _ => t
  }
}

///|
fn make_placeholder_field(
  name : String,
  comp : @cil.CompInfo,
) -> @cil.FieldInfo {
  {
    fcomp: comp,
    fname: name,
    ftype: @cil.TInt(@cil.IInt, []),
    fbitfield: None,
    fattr: [],
    floc: @cil.unknown_location,
  }
}

///|
fn conv_cabs_attr(env : ConvEnv, a : CabsAttribute) -> @cil.Attribute {
  let params : Array[@cil.AttrParam] = []
  for e in a.args {
    let p = conv_expr_to_attrparam(env, e) catch { _ => @cil.AInt(0) }
    params.push(p)
  }
  { name: a.name, params }
}

///|
fn conv_name_attrs(
  env : ConvEnv,
  attrs : Array[CabsAttribute],
) -> Array[@cil.Attribute] {
  let out : Array[@cil.Attribute] = []
  for a in attrs {
    out.push(conv_cabs_attr(env, a))
  }
  out
}

///|
fn conv_block_attrs(
  env : ConvEnv,
  attrs : Array[CabsAttribute],
) -> Array[@cil.Attribute] {
  conv_name_attrs(env, attrs)
}

///|
fn dummy_var() -> @cil.VarInfo {
  {
    vname: "__dummy",
    vtype: @cil.TInt(@cil.IInt, []),
    vattr: [],
    vstorage: @cil.NoStorage,
    vglob: false,
    vinline: false,
    vdecl: @cil.unknown_location,
    vinit: { init: None },
    vid: 0,
    vaddrof: false,
    vreferenced: false,
    vdescr: "",
    vdescrpure: true,
  }
}

///|
pub fn conv_loc(loc : CabsLoc) -> @cil.Location {
  { line: loc.lineno, file: loc.filename, byte: loc.byteno }
}

///|
fn conv_unop(op : CabsUnaryOp) -> @cil.UnOp? {
  match op {
    Minus => Some(@cil.Neg)
    Bnot => Some(@cil.BNot)
    Not => Some(@cil.LNot)
    _ => None
  }
}

///|
fn conv_binop(op : CabsBinaryOp) -> @cil.BinOp? {
  match op {
    Add => Some(@cil.PlusA)
    Sub => Some(@cil.MinusA)
    Mul => Some(@cil.Mult)
    Div => Some(@cil.Div)
    Mod => Some(@cil.Mod)
    And => Some(@cil.LAnd)
    Or => Some(@cil.LOr)
    Band => Some(@cil.BAnd)
    Bor => Some(@cil.BOr)
    Xor => Some(@cil.BXor)
    Shl => Some(@cil.Shiftlt)
    Shr => Some(@cil.Shiftrt)
    Eq => Some(@cil.Eq)
    Ne => Some(@cil.Ne)
    Lt => Some(@cil.Lt)
    Gt => Some(@cil.Gt)
    Le => Some(@cil.Le)
    Ge => Some(@cil.Ge)
    _ => None
  }
}

///|
fn conv_type_specifier(
  env : ConvEnv,
  spec : Specifier,
) -> @cil.Typ raise ConversionError {
  let Specifier(specs) = spec
  let mut base_type : @cil.Typ? = None
  let type_attrs : Array[@cil.Attribute] = []
  let mut is_signed = false
  let mut is_unsigned = false
  let mut is_short = false
  let mut is_long = false
  let mut is_longlong = false
  for elem in specs {
    match elem {
      SpecCV(cv) => {
        let name = match cv {
          CvConst => "const"
          CvVolatile => "volatile"
          CvRestrict => "restrict"
        }
        type_attrs.push({ name, params: [] })
      }
      SpecAttr(attr) => type_attrs.push(conv_cabs_attr(env, attr))
      SpecType(ts) =>
        match ts {
          Tvoid => base_type = Some(@cil.TVoid([]))
          Tchar =>
            base_type = Some(
              @cil.TInt(
                if is_unsigned {
                  @cil.IUChar
                } else if is_signed {
                  @cil.ISChar
                } else {
                  @cil.IChar
                },
                [],
              ),
            )
          Tshort => is_short = true
          Tint => base_type = Some(@cil.TInt(@cil.IInt, []))
          Tlong => if is_long { is_longlong = true } else { is_long = true }
          Tfloat => base_type = Some(@cil.TFloat(@cil.FFloat, []))
          Tdouble =>
            base_type = Some(
              @cil.TFloat(
                if is_long {
                  @cil.FLongDouble
                } else {
                  @cil.FDouble
                },
                [],
              ),
            )
          Tsigned => is_signed = true
          Tunsigned => is_unsigned = true
          Tbool => base_type = Some(@cil.TInt(@cil.IBool, []))
          Tnamed(name) => {
            let entry = match env.env.get(name) {
              Some(e) => Some(e)
              None => env.genv.get(name)
            }
            match entry {
              Some(EnvTypeDef(ti)) => base_type = Some(@cil.TNamed(ti, []))
              _ => raise ConversionError("Unknown type name: \{name}")
            }
          }
          Tstruct(name, fields_opt, _) => {
            let ci = conv_comp(env, true, name, fields_opt)
            base_type = Some(@cil.TComp(ci, []))
          }
          Tunion(name, fields_opt, _) => {
            let ci = conv_comp(env, false, name, fields_opt)
            base_type = Some(@cil.TComp(ci, []))
          }
          Tenum(name, items_opt, _) => {
            let ei = conv_enum(env, name, items_opt)
            base_type = Some(@cil.TEnum(ei, []))
          }
          Tint64 => base_type = Some(@cil.TInt(@cil.ILongLong, []))
          TtypeofE(expr) => {
            let (_, cil_expr, _) = conv_exp(env, expr)
            base_type = Some(@cil.type_of(cil_expr))
          }
          TtypeofT(inner_spec, decl) => {
            let inner_base = conv_type_specifier(env, inner_spec)
            let full_type = conv_decl_type(env, inner_base, decl)
            base_type = Some(full_type)
          }
        }
      _ => ()
    }
  }
  let final_type = match base_type {
    Some(t) => t
    None =>
      if is_unsigned {
        if is_longlong {
          @cil.TInt(@cil.IULongLong, [])
        } else if is_long {
          @cil.TInt(@cil.IULong, [])
        } else if is_short {
          @cil.TInt(@cil.IUShort, [])
        } else {
          @cil.TInt(@cil.IUInt, [])
        }
      } else if is_longlong {
        @cil.TInt(@cil.ILongLong, [])
      } else if is_long {
        @cil.TInt(@cil.ILong, [])
      } else if is_short {
        @cil.TInt(@cil.IShort, [])
      } else {
        @cil.TInt(@cil.IInt, [])
      }
  }
  fn add_attrs(t : @cil.Typ, attrs : Array[@cil.Attribute]) -> @cil.Typ {
    if attrs.is_empty() {
      return t
    }
    match t {
      @cil.TVoid(a) => @cil.TVoid(a + attrs)
      @cil.TInt(k, a) => @cil.TInt(k, a + attrs)
      @cil.TFloat(k, a) => @cil.TFloat(k, a + attrs)
      @cil.TPtr(bt, a) => @cil.TPtr(bt, a + attrs)
      @cil.TArray(bt, len, a) => @cil.TArray(bt, len, a + attrs)
      @cil.TFun(rt, ps, va, a) => @cil.TFun(rt, ps, va, a + attrs)
      @cil.TNamed(ti, a) => @cil.TNamed(ti, a + attrs)
      @cil.TComp(ci, a) => @cil.TComp(ci, a + attrs)
      @cil.TEnum(ei, a) => @cil.TEnum(ei, a + attrs)
      @cil.TBuiltinVaList(a) => @cil.TBuiltinVaList(a + attrs)
    }
  }

  add_attrs(final_type, type_attrs)
}

///|
fn conv_decl_type(
  env : ConvEnv,
  base : @cil.Typ,
  decl : DeclType,
) -> @cil.Typ raise ConversionError {
  match decl {
    JustBase => base
    Ptr(attrs, inner) => {
      let ptr_attrs : Array[@cil.Attribute] = []
      for a in attrs {
        ptr_attrs.push({ name: a.name, params: [] })
      }
      let ptr_type = @cil.TPtr(base, ptr_attrs)
      conv_decl_type(env, ptr_type, inner)
    }
    Array(inner, _, size_expr) => {
      let size_opt = match size_expr {
        Nothing => None
        _ => {
          let (_, e, _) = conv_exp(env, size_expr)
          Some(e)
        }
      }
      let arr_type = @cil.TArray(base, size_opt, [])
      conv_decl_type(env, arr_type, inner)
    }
    Proto(inner, params, is_vararg) => {
      let param_types : Array[(String, @cil.Typ, Array[@cil.Attribute])] = []
      for p in params {
        let param_base = conv_type_specifier(env, p.spec)
        let param_type = conv_decl_type(env, param_base, p.name.decl_type)
        param_types.push(
          (p.name.name, param_type, conv_name_attrs(env, p.name.attrs)),
        )
      }
      let fun_type = @cil.TFun(base, Some(param_types), is_vararg, [])
      conv_decl_type(env, fun_type, inner)
    }
    ParenType(_, inner, _) => conv_decl_type(env, base, inner)
  }
}

///|
fn conv_comp(
  env : ConvEnv,
  is_struct : Bool,
  name : String,
  fields_opt : Array[FieldGroup]?,
) -> @cil.CompInfo {
  if name == "" {
    let ci : @cil.CompInfo = {
      cstruct: is_struct,
      cname: name,
      ckey: @cil.new_comp_key(),
      cfields: [],
      cattr: [],
      cdefined: not(fields_opt is None),
      creferenced: false,
    }
    match fields_opt {
      Some(field_groups) =>
        for fg in field_groups {
          let base_type = conv_type_specifier(env, fg.spec) catch {
            _ => @cil.TInt(@cil.IInt, [])
          }
          for field_decl in fg.fields {
            let (name_info, bitfield_opt) = field_decl
            if name_info.name == "" {
              continue
            }
            let field_type = conv_decl_type(env, base_type, name_info.decl_type) catch {
              _ => base_type
            }
            let bitfield = match bitfield_opt {
              Some(_) => Some(32)
              None => None
            }
            let fattr = conv_name_attrs(env, name_info.attrs)
            let fi : @cil.FieldInfo = {
              fcomp: ci,
              fname: name_info.name,
              ftype: field_type,
              fbitfield: bitfield,
              fattr,
              floc: conv_loc(name_info.loc),
            }
            ci.cfields.push(fi)
          }
        }
      None => ()
    }
    return ci
  }
  match env.comps.get(name) {
    Some(existing_ci) => {
      match fields_opt {
        Some(field_groups) =>
          if existing_ci.cfields.is_empty() {
            for fg in field_groups {
              let base_type = conv_type_specifier(env, fg.spec) catch {
                _ => @cil.TInt(@cil.IInt, [])
              }
              for field_decl in fg.fields {
                let (name_info, bitfield_opt) = field_decl
                let field_type = conv_decl_type(
                  env,
                  base_type,
                  name_info.decl_type,
                ) catch {
                  _ => base_type
                }
                let bitfield = match bitfield_opt {
                  Some(_) => Some(32)
                  None => None
                }
                let fattr = conv_name_attrs(env, name_info.attrs)
                let fi : @cil.FieldInfo = {
                  fcomp: existing_ci,
                  fname: name_info.name,
                  ftype: field_type,
                  fbitfield: bitfield,
                  fattr,
                  floc: conv_loc(name_info.loc),
                }
                existing_ci.cfields.push(fi)
              }
            }
            existing_ci.cdefined = true
          }
        None => ()
      }
      existing_ci
    }
    None => {
      let ci : @cil.CompInfo = {
        cstruct: is_struct,
        cname: name,
        ckey: @cil.new_comp_key(),
        cfields: [],
        cattr: [],
        cdefined: not(fields_opt is None),
        creferenced: false,
      }
      env.comps[name] = ci
      match fields_opt {
        Some(field_groups) =>
          for fg in field_groups {
            let base_type = conv_type_specifier(env, fg.spec) catch {
              _ => @cil.TInt(@cil.IInt, [])
            }
            for field_decl in fg.fields {
              let (name_info, bitfield_opt) = field_decl
              if name_info.name == "" {
                continue
              }
              let field_type = conv_decl_type(
                env,
                base_type,
                name_info.decl_type,
              ) catch {
                _ => base_type
              }
              let bitfield = match bitfield_opt {
                Some(_) => Some(32)
                None => None
              }
              let fattr = conv_name_attrs(env, name_info.attrs)
              let fi : @cil.FieldInfo = {
                fcomp: ci,
                fname: name_info.name,
                ftype: field_type,
                fbitfield: bitfield,
                fattr,
                floc: conv_loc(name_info.loc),
              }
              ci.cfields.push(fi)
            }
          }
        None => ()
      }
      ci
    }
  }
}

///|
fn sizeof_basic(t : @cil.Typ) -> Int64? {
  match unroll_type(t) {
    @cil.TVoid(_) => Some(1L)
    @cil.TInt(ik, _) =>
      Some(
        match ik {
          @cil.IBool | @cil.IChar | @cil.ISChar | @cil.IUChar => 1L
          @cil.IShort | @cil.IUShort => 2L
          @cil.IInt | @cil.IUInt => 4L
          @cil.ILong | @cil.IULong => 8L
          @cil.ILongLong | @cil.IULongLong => 8L
        },
      )
    @cil.TFloat(fk, _) =>
      Some(
        match fk {
          @cil.FFloat => 4L
          @cil.FDouble => 8L
          @cil.FLongDouble => 16L
        },
      )
    @cil.TPtr(_, _) => Some(8L)
    _ => None
  }
}

///|
fn eval_const_int64(env : ConvEnv, e : CabsExpression) -> Int64? {
  match e {
    Nothing => None
    Paren(inner) => eval_const_int64(env, inner)
    Constant(ConstInt(s)) => Some(parse_int64(s))
    Unary(op, inner) =>
      match eval_const_int64(env, inner) {
        Some(v) =>
          Some(
            match op {
              Minus => 0L - v
              Plus => v
              Bnot => v ^ -1L
              Not => if v == 0L { 1L } else { 0L }
              _ => v
            },
          )
        None => None
      }
    Binary(op, e1, e2) =>
      match (eval_const_int64(env, e1), eval_const_int64(env, e2)) {
        (Some(a), Some(b)) =>
          Some(
            match op {
              Add => a + b
              Sub => a - b
              Mul => a * b
              Div => if b == 0L { 0L } else { a / b }
              Mod => if b == 0L { 0L } else { a % b }
              Band => a & b
              Bor => a | b
              Xor => a ^ b
              Shl => a << b.to_int()
              Shr => a >> b.to_int()
              Lt => if a < b { 1L } else { 0L }
              Gt => if a > b { 1L } else { 0L }
              Le => if a <= b { 1L } else { 0L }
              Ge => if a >= b { 1L } else { 0L }
              Eq => if a == b { 1L } else { 0L }
              Ne => if a != b { 1L } else { 0L }
              And => if a != 0L && b != 0L { 1L } else { 0L }
              Or => if a != 0L || b != 0L { 1L } else { 0L }
              _ => a
            },
          )
        _ => None
      }
    Question(cond, e_true, e_false) =>
      match eval_const_int64(env, cond) {
        Some(c) =>
          if c != 0L {
            eval_const_int64(env, e_true)
          } else {
            eval_const_int64(env, e_false)
          }
        None => None
      }
    Cast((_, _), init_expr) =>
      match init_expr {
        SingleInit(inner) => eval_const_int64(env, inner)
        _ => None
      }
    Variable(n) =>
      match env.genv.get(n) {
        Some(
          EnvEnum(
            @cil.Const(@cil.CEnum(@cil.Const(@cil.CInt64(v, _, _)), _, _)),
            _
          )
        ) => Some(v)
        Some(EnvEnum(@cil.Const(@cil.CInt64(v, _, _)), _)) => Some(v)
        _ => None
      }
    TypeSizeof(spec, decl) => {
      let bt = conv_type_specifier(env, spec) catch {
        _ => @cil.TInt(@cil.IInt, [])
      }
      let t = conv_decl_type(env, bt, decl) catch { _ => bt }
      sizeof_basic(t)
    }
    ExprSizeof(_) => None
    _ => None
  }
}

///|
fn conv_enum(
  env : ConvEnv,
  name : String,
  items_opt : Array[EnumItem]?,
) -> @cil.EnumInfo raise ConversionError {
  let ei : @cil.EnumInfo = {
    ename: name,
    eitems: [],
    eattr: [],
    ereferenced: false,
    ekind: @cil.IInt,
  }
  let enum_typ = @cil.TEnum(ei, [])
  match items_opt {
    Some(items) => {
      let mut next_val = 0L
      for item in items {
        let item_val = match item.value {
          Nothing => next_val
          _ =>
            match eval_const_int64(env, item.value) {
              Some(v) => v
              None =>
                raise ConversionError("Enum value is not an integer constant")
            }
        }
        // Use folded constant value for eitems
        let def_exp = @cil.Const(@cil.CInt64(item_val, @cil.IInt, None))
        ei.eitems.push((item.name, def_exp, conv_loc(item.loc)))
        let enum_const = @cil.Const(
          @cil.CEnum(
            @cil.Const(@cil.CInt64(item_val, @cil.IInt, None)),
            item.name,
            ei,
          ),
        )
        env.genv[item.name] = EnvEnum(enum_const, enum_typ)
        next_val = item_val + 1L
      }
    }
    None => ()
  }
  ei
}

///|
priv enum ExpAction {
  ADrop
  AExp
  ASet(@cil.LVal, @cil.Typ)
}

///|
fn types_equal(t1 : @cil.Typ, t2 : @cil.Typ) -> Bool {
  match (t1, t2) {
    (@cil.TInt(ik1, _), @cil.TInt(ik2, _)) => ik1 == ik2
    (@cil.TFloat(fk1, _), @cil.TFloat(fk2, _)) => fk1 == fk2
    (@cil.TVoid(_), @cil.TVoid(_)) => true
    (@cil.TPtr(@cil.TVoid(_), _), @cil.TPtr(_, _)) => true
    (@cil.TPtr(_, _), @cil.TPtr(@cil.TVoid(_), _)) => true
    (@cil.TPtr(pt1, _), @cil.TPtr(pt2, _)) => types_equal(pt1, pt2)
    (@cil.TArray(et1, _, _), @cil.TArray(et2, _, _)) => types_equal(et1, et2)
    (@cil.TFun(rt1, _, _, _), @cil.TFun(rt2, _, _, _)) => types_equal(rt1, rt2)
    (@cil.TComp(ci1, _), @cil.TComp(ci2, _)) => ci1.ckey == ci2.ckey
    (@cil.TEnum(ei1, _), @cil.TEnum(ei2, _)) => ei1.ename == ei2.ename
    _ => false
  }
}

///|
fn cast_to(from_type : @cil.Typ, to_type : @cil.Typ, e : @cil.Exp) -> @cil.Exp {
  if types_equal(from_type, to_type) {
    e
  } else {
    @cil.CastE(to_type, e)
  }
}

///|
pub fn conv_exp_drop(env : ConvEnv, e : CabsExpression) -> Array[@cil.Instr] {
  let (instrs, _, _) = conv_exp_impl(env, e, ADrop)
  instrs
}

///|
pub fn conv_exp(
  env : ConvEnv,
  e : CabsExpression,
) -> (Array[@cil.Instr], @cil.Exp, @cil.Typ) {
  conv_exp_impl(env, e, AExp)
}

///|
fn conv_exp_set(
  env : ConvEnv,
  e : CabsExpression,
  lv : @cil.LVal,
  lvt : @cil.Typ,
) -> (Array[@cil.Instr], @cil.Exp, @cil.Typ) {
  match e {
    Call(_, _) => conv_exp_impl(env, e, ASet(lv, lvt))
    _ => {
      let (instrs, exp, typ) = conv_exp_impl(env, e, AExp)
      let casted_exp = cast_to(typ, lvt, exp)
      instrs.push(@cil.Set(lv, casted_exp, @cil.unknown_location))
      (instrs, @cil.Lval(lv), lvt)
    }
  }
}

///|
fn conv_exp_impl(
  env : ConvEnv,
  e : CabsExpression,
  what : ExpAction,
) -> (Array[@cil.Instr], @cil.Exp, @cil.Typ) {
  let instrs : Array[@cil.Instr] = []
  let int_type = @cil.TInt(@cil.IInt, [])
  match e {
    Nothing => (instrs, @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), int_type)
    Constant(c) => {
      let (exp, typ) = conv_constant(c)
      (instrs, exp, typ)
    }
    Variable(name) => {
      let entry = match env.env.get(name) {
        Some(e) => Some(e)
        None => env.genv.get(name)
      }
      match entry {
        Some(EnvVar(vi)) => {
          let lval : @cil.LVal = { host: @cil.Var(vi), offset: @cil.NoOffset }
          (instrs, @cil.Lval(lval), vi.vtype)
        }
        Some(EnvEnum(exp, typ)) => (instrs, exp, typ)
        _ => {
          let vi : @cil.VarInfo = {
            vname: name,
            vtype: int_type,
            vattr: [],
            vstorage: @cil.Extern,
            vglob: true,
            vinline: false,
            vdecl: @cil.unknown_location,
            vinit: { init: None },
            vid: @cil.new_vid(),
            vaddrof: false,
            vreferenced: true,
            vdescr: "",
            vdescrpure: true,
          }
          env.genv[name] = EnvVar(vi)
          let lval : @cil.LVal = { host: @cil.Var(vi), offset: @cil.NoOffset }
          (instrs, @cil.Lval(lval), int_type)
        }
      }
    }
    Unary(op, sub) => {
      let (sub_instrs, sub_exp, sub_type) = conv_exp(env, sub)
      instrs.append(sub_instrs)
      match op {
        Addrof =>
          match sub_exp {
            Lval(lv) => (instrs, @cil.AddrOf(lv), @cil.TPtr(sub_type, []))
            _ => (instrs, sub_exp, sub_type)
          }
        Memof => {
          let lv = @cil.LVal::{ host: @cil.Mem(sub_exp), offset: @cil.NoOffset }
          let result_type = match sub_type {
            TPtr(t, _) => t
            _ => int_type
          }
          (instrs, @cil.Lval(lv), result_type)
        }
        Preincr | Predecr => {
          let binop = match op {
            Preincr => @cil.PlusA
            _ => @cil.MinusA
          }
          match sub_exp {
            Lval(lv) => {
              let one = @cil.Const(@cil.CInt64(1L, @cil.IInt, None))
              let new_val = @cil.BinOp(binop, sub_exp, one, sub_type)
              let set_instr : @cil.Instr = @cil.Set(
                lv, new_val, @cil.unknown_location,
              )
              instrs.push(set_instr)
              (instrs, @cil.Lval(lv), sub_type)
            }
            _ => (instrs, sub_exp, sub_type)
          }
        }
        Posincr | Posdecr => {
          let binop = match op {
            Posincr => @cil.PlusA
            _ => @cil.MinusA
          }
          match sub_exp {
            Lval(lv) => {
              let one = @cil.Const(@cil.CInt64(1L, @cil.IInt, None))
              let new_val = @cil.BinOp(binop, sub_exp, one, sub_type)
              let set_instr = @cil.Set(lv, new_val, @cil.unknown_location)
              instrs.push(set_instr)
              (instrs, sub_exp, sub_type)
            }
            _ => (instrs, sub_exp, sub_type)
          }
        }
        _ =>
          match conv_unop(op) {
            Some(cil_op) =>
              (instrs, @cil.UnOp(cil_op, sub_exp, sub_type), sub_type)
            None => (instrs, sub_exp, sub_type)
          }
      }
    }
    Binary(op, left, right) =>
      match conv_binop(op) {
        Some(cil_op) => {
          let (left_instrs, left_exp, left_type) = conv_exp(env, left)
          let (right_instrs, right_exp, _) = conv_exp(env, right)
          instrs.append(left_instrs)
          instrs.append(right_instrs)
          (
            instrs,
            @cil.BinOp(cil_op, left_exp, right_exp, left_type),
            left_type,
          )
        }
        None =>
          match op {
            Assign => {
              let (left_instrs, left_exp, left_type) = conv_exp(env, left)
              instrs.append(left_instrs)
              match left_exp {
                Lval(lv) => {
                  let (right_instrs, _, _) = conv_exp_set(
                    env, right, lv, left_type,
                  )
                  instrs.append(right_instrs)
                  (instrs, left_exp, left_type)
                }
                _ => {
                  let (right_instrs, right_exp, _) = conv_exp(env, right)
                  instrs.append(right_instrs)
                  (instrs, right_exp, left_type)
                }
              }
            }
            AddAssign
            | SubAssign
            | MulAssign
            | DivAssign
            | ModAssign
            | BandAssign
            | BorAssign
            | XorAssign
            | ShlAssign
            | ShrAssign => {
              let (left_instrs, left_exp, left_type) = conv_exp(env, left)
              let (right_instrs, right_exp, _) = conv_exp(env, right)
              instrs.append(left_instrs)
              instrs.append(right_instrs)
              match left_exp {
                Lval(lv) => {
                  let binop : @cil.BinOp = match op {
                    AddAssign => @cil.PlusA
                    SubAssign => @cil.MinusA
                    MulAssign => @cil.Mult
                    DivAssign => @cil.Div
                    ModAssign => @cil.Mod
                    BandAssign => @cil.BAnd
                    BorAssign => @cil.BOr
                    XorAssign => @cil.BXor
                    ShlAssign => @cil.Shiftlt
                    _ => @cil.Shiftrt
                  }
                  let new_val = @cil.BinOp(
                    binop, left_exp, right_exp, left_type,
                  )
                  instrs.push(@cil.Set(lv, new_val, @cil.unknown_location))
                  (instrs, left_exp, left_type)
                }
                _ => (instrs, left_exp, left_type)
              }
            }
            _ => {
              let (left_instrs, left_exp, left_type) = conv_exp(env, left)
              instrs.append(left_instrs)
              (instrs, left_exp, left_type)
            }
          }
      }
    Question(cond, then_e, else_e) => {
      let (cond_instrs, cond_exp, _) = conv_exp(env, cond)
      let (then_instrs, then_exp, then_type) = conv_exp(env, then_e)
      let (else_instrs, else_exp, _) = conv_exp(env, else_e)
      instrs.append(cond_instrs)
      instrs.append(then_instrs)
      instrs.append(else_instrs)
      (
        instrs,
        @cil.Question(cond_exp, then_exp, else_exp, then_type),
        then_type,
      )
    }
    Call(func, args) => {
      let (func_instrs, func_exp, func_type) = conv_exp_impl(env, func, AExp)
      instrs.append(func_instrs)
      let arg_exps : Array[@cil.Exp] = []
      for arg in args {
        let (arg_instrs, arg_exp, _) = conv_exp_impl(env, arg, AExp)
        instrs.append(arg_instrs)
        arg_exps.push(arg_exp)
      }
      let ret_type = match func_type {
        TFun(ret, _, _, _) => ret
        TPtr(TFun(ret, _, _, _), _) => ret
        _ => int_type
      }
      match what {
        ADrop => {
          instrs.push(
            @cil.Call(None, func_exp, arg_exps, @cil.unknown_location),
          )
          (instrs, @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), ret_type)
        }
        ASet(lv, lvt) =>
          match ret_type {
            TVoid(_) => {
              instrs.push(
                @cil.Call(None, func_exp, arg_exps, @cil.unknown_location),
              )
              (instrs, @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), ret_type)
            }
            _ =>
              if types_equal(ret_type, lvt) {
                instrs.push(
                  @cil.Call(Some(lv), func_exp, arg_exps, @cil.unknown_location),
                )
                (instrs, @cil.Lval(lv), lvt)
              } else {
                let temp_var = make_temp_var(env, "__call_result", ret_type)
                let temp_lv : @cil.LVal = {
                  host: @cil.Var(temp_var),
                  offset: @cil.NoOffset,
                }
                instrs.push(
                  @cil.Call(
                    Some(temp_lv),
                    func_exp,
                    arg_exps,
                    @cil.unknown_location,
                  ),
                )
                let casted = cast_to(ret_type, lvt, @cil.Lval(temp_lv))
                instrs.push(@cil.Set(lv, casted, @cil.unknown_location))
                (instrs, @cil.Lval(lv), lvt)
              }
          }
        AExp =>
          match ret_type {
            TVoid(_) => {
              instrs.push(
                @cil.Call(None, func_exp, arg_exps, @cil.unknown_location),
              )
              (instrs, @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), ret_type)
            }
            _ => {
              let result_var = make_temp_var(env, "__retval", ret_type)
              let result_lval : @cil.LVal = {
                host: @cil.Var(result_var),
                offset: @cil.NoOffset,
              }
              instrs.push(
                @cil.Call(
                  Some(result_lval),
                  func_exp,
                  arg_exps,
                  @cil.unknown_location,
                ),
              )
              (instrs, @cil.Lval(result_lval), ret_type)
            }
          }
      }
    }
    Index(arr, idx) => {
      let (arr_instrs, arr_exp, arr_type) = conv_exp(env, arr)
      let (idx_instrs, idx_exp, _) = conv_exp(env, idx)
      instrs.append(arr_instrs)
      instrs.append(idx_instrs)
      let elem_type = match arr_type {
        TArray(t, _, _) => t
        TPtr(t, _) => t
        _ => int_type
      }
      let ptr_exp = @cil.BinOp(@cil.IndexPI, arr_exp, idx_exp, arr_type)
      let lv : @cil.LVal = { host: @cil.Mem(ptr_exp), offset: @cil.NoOffset }
      (instrs, @cil.Lval(lv), elem_type)
    }
    MemberOf(obj, field) => {
      let (obj_instrs, obj_exp, obj_type) = conv_exp(env, obj)
      instrs.append(obj_instrs)
      let base_lv : @cil.LVal = match obj_exp {
        Lval(lv) => lv
        CastE(_, inner) =>
          match inner {
            Lval(lv) => lv
            _ => { host: @cil.Var(dummy_var()), offset: @cil.NoOffset }
          }
        _ => { host: @cil.Var(dummy_var()), offset: @cil.NoOffset }
      }
      let unrolled = unroll_type(obj_type)
      match unrolled {
        TComp(comp, _) =>
          match find_field(field, comp.cfields) {
            Some(fi) => {
              let new_offset = add_offset(
                base_lv.offset,
                @cil.Field(fi, @cil.NoOffset),
              )
              let new_lv : @cil.LVal = {
                host: base_lv.host,
                offset: new_offset,
              }
              (instrs, @cil.Lval(new_lv), fi.ftype)
            }
            None => {
              let placeholder_fi = make_placeholder_field(field, comp)
              let new_offset = add_offset(
                base_lv.offset,
                @cil.Field(placeholder_fi, @cil.NoOffset),
              )
              let new_lv : @cil.LVal = {
                host: base_lv.host,
                offset: new_offset,
              }
              (instrs, @cil.Lval(new_lv), int_type)
            }
          }
        _ => (instrs, obj_exp, int_type)
      }
    }
    MemberOfPtr(obj, field) => {
      let (obj_instrs, obj_exp, obj_type) = conv_exp(env, obj)
      instrs.append(obj_instrs)
      let pointee_type = match obj_type {
        TPtr(t, _) => t
        TArray(t, _, _) => t
        _ => int_type
      }
      let unrolled = unroll_type(pointee_type)
      match unrolled {
        TComp(comp, _) =>
          match find_field(field, comp.cfields) {
            Some(fi) => {
              let lv : @cil.LVal = {
                host: @cil.Mem(obj_exp),
                offset: @cil.Field(fi, @cil.NoOffset),
              }
              (instrs, @cil.Lval(lv), fi.ftype)
            }
            None => {
              let placeholder_fi = make_placeholder_field(field, comp)
              let lv : @cil.LVal = {
                host: @cil.Mem(obj_exp),
                offset: @cil.Field(placeholder_fi, @cil.NoOffset),
              }
              (instrs, @cil.Lval(lv), int_type)
            }
          }
        _ => {
          let lv : @cil.LVal = {
            host: @cil.Mem(obj_exp),
            offset: @cil.NoOffset,
          }
          (instrs, @cil.Lval(lv), unrolled)
        }
      }
    }
    Paren(inner) => conv_exp(env, inner)
    ExprSizeof(inner) => {
      let (_, _, t) = conv_exp(env, inner)
      (instrs, @cil.SizeOf(t), @cil.TInt(@cil.IULong, []))
    }
    TypeSizeof(spec, decl) => {
      let base = conv_type_specifier(env, spec) catch { _ => int_type }
      let t = conv_decl_type(env, base, decl) catch { _ => base }
      (instrs, @cil.SizeOf(t), @cil.TInt(@cil.IULong, []))
    }
    Cast((spec, decl), init_expr) => {
      let base = conv_type_specifier(env, spec) catch { _ => int_type }
      let cast_type = conv_decl_type(env, base, decl) catch { _ => base }
      let (sub_instrs, sub_exp, _) = match init_expr {
        SingleInit(e) => conv_exp(env, e)
        _ => ([], @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), int_type)
      }
      instrs.append(sub_instrs)
      (instrs, @cil.CastE(cast_type, sub_exp), cast_type)
    }
    Comma(exprs) => {
      let mut last_exp = @cil.Const(@cil.CInt64(0L, @cil.IInt, None))
      let mut last_type = int_type
      for i, expr in exprs {
        if i == exprs.length() - 1 {
          let (sub_instrs, sub_exp, sub_type) = conv_exp(env, expr)
          instrs.append(sub_instrs)
          last_exp = sub_exp
          last_type = sub_type
        } else {
          let sub_instrs = conv_exp_drop(env, expr)
          instrs.append(sub_instrs)
        }
      }
      (instrs, last_exp, last_type)
    }
    _ => (instrs, @cil.Const(@cil.CInt64(0L, @cil.IInt, None)), int_type)
  }
}

///|
fn conv_constant(c : CabsConstant) -> (@cil.Exp, @cil.Typ) {
  match c {
    ConstInt(s) => {
      let value = parse_int64(s)
      (
        @cil.Const(@cil.CInt64(value, @cil.IInt, Some(s))),
        @cil.TInt(@cil.IInt, []),
      )
    }
    ConstFloat(s) => {
      let value = parse_double(s)
      (
        @cil.Const(@cil.CReal(value, @cil.FDouble, Some(s))),
        @cil.TFloat(@cil.FDouble, []),
      )
    }
    ConstChar(chars) =>
      if chars.is_empty() {
        (@cil.Const(@cil.CChr('\u{00}')), @cil.TInt(@cil.IChar, []))
      } else {
        (
          @cil.Const(@cil.CChr(Int::to_char(chars[0].to_int()).unwrap())),
          @cil.TInt(@cil.IChar, []),
        )
      }
    ConstString(s) =>
      (@cil.Const(@cil.CStr(s)), @cil.TPtr(@cil.TInt(@cil.IChar, []), []))
    ConstWchar(chars) =>
      (@cil.Const(@cil.CWStr(chars)), @cil.TPtr(@cil.TInt(@cil.IInt, []), []))
    ConstWstring(chars) =>
      (@cil.Const(@cil.CWStr(chars)), @cil.TPtr(@cil.TInt(@cil.IInt, []), []))
  }
}

///|
fn conv_expr_to_attrparam(
  env : ConvEnv,
  expr : CabsExpression,
) -> @cil.AttrParam raise ConversionError {
  match expr {
    Nothing => @cil.AInt(0)
    Constant(c) =>
      match c {
        ConstInt(s) => @cil.AInt(parse_int64(s).to_int())
        ConstString(s) => @cil.AStr(s)
        ConstFloat(s) => @cil.AStr(s)
        ConstChar(chars) =>
          if chars.is_empty() {
            @cil.AInt(0)
          } else {
            @cil.AInt(chars[0].to_int())
          }
        ConstWchar(chars) =>
          if chars.is_empty() {
            @cil.AInt(0)
          } else {
            @cil.AInt(chars[0].to_int())
          }
        ConstWstring(chars) => {
          let s = chars
            .map(fn(c) { Int::to_char(c.to_int()).unwrap().to_string() })
            .join("")
          @cil.AStr(s)
        }
      }
    Variable(name) => @cil.ACons(name, [])
    Unary(op, sub) => {
      let sub_param = conv_expr_to_attrparam(env, sub)
      match op {
        Minus => @cil.AUnOp(@cil.Neg, sub_param)
        Bnot => @cil.AUnOp(@cil.BNot, sub_param)
        Not => @cil.AUnOp(@cil.LNot, sub_param)
        Addrof => @cil.AAddrOf(sub_param)
        Memof => @cil.AStar(sub_param)
        _ => sub_param
      }
    }
    Binary(op, left, right) => {
      let left_param = conv_expr_to_attrparam(env, left)
      let right_param = conv_expr_to_attrparam(env, right)
      let cil_op : @cil.BinOp = match op {
        Add => @cil.PlusA
        Sub => @cil.MinusA
        Mul => @cil.Mult
        Div => @cil.Div
        Mod => @cil.Mod
        And => @cil.LAnd
        Or => @cil.LOr
        Band => @cil.BAnd
        Bor => @cil.BOr
        Xor => @cil.BXor
        Shl => @cil.Shiftlt
        Shr => @cil.Shiftrt
        Eq => @cil.Eq
        Ne => @cil.Ne
        Lt => @cil.Lt
        Gt => @cil.Gt
        Le => @cil.Le
        Ge => @cil.Ge
        _ => @cil.PlusA
      }
      @cil.ABinOp(cil_op, left_param, right_param)
    }
    Question(cond, then_expr, else_expr) => {
      let cond_param = conv_expr_to_attrparam(env, cond)
      let then_param = conv_expr_to_attrparam(env, then_expr)
      let else_param = conv_expr_to_attrparam(env, else_expr)
      @cil.AQuestion(cond_param, then_param, else_param)
    }
    Index(base, idx) => {
      let base_param = conv_expr_to_attrparam(env, base)
      let idx_param = conv_expr_to_attrparam(env, idx)
      @cil.AIndex(base_param, idx_param)
    }
    MemberOf(base, field) => {
      let base_param = conv_expr_to_attrparam(env, base)
      @cil.ADot(base_param, field)
    }
    MemberOfPtr(base, field) => {
      let base_param = conv_expr_to_attrparam(env, base)
      @cil.ADot(@cil.AStar(base_param), field)
    }
    Call(fn_expr, args) =>
      match fn_expr {
        Variable(name) => {
          let arg_params = args.map(fn(a) { conv_expr_to_attrparam(env, a) })
          @cil.ACons(name, arg_params)
        }
        _ => @cil.AInt(0)
      }
    TypeSizeof(spec, decl) => {
      let base_type = conv_type_specifier(env, spec)
      let full_type = conv_decl_type(env, base_type, decl)
      @cil.ASizeOf(full_type)
    }
    ExprSizeof(sub) => {
      let sub_param = conv_expr_to_attrparam(env, sub)
      @cil.ASizeOfE(sub_param)
    }
    TypeAlignof(spec, decl) => {
      let base_type = conv_type_specifier(env, spec)
      let full_type = conv_decl_type(env, base_type, decl)
      @cil.AAlignOf(full_type)
    }
    ExprAlignof(sub) => {
      let sub_param = conv_expr_to_attrparam(env, sub)
      @cil.AAlignOfE(sub_param)
    }
    Paren(sub) => conv_expr_to_attrparam(env, sub)
    _ => @cil.AInt(0)
  }
}

///|
fn conv_expr_to_attr(
  env : ConvEnv,
  expr : CabsExpression,
) -> @cil.Attribute raise ConversionError {
  match expr {
    Call(Variable(name), args) => {
      let params = args.map(fn(a) { conv_expr_to_attrparam(env, a) })
      { name, params }
    }
    Variable(name) => { name, params: [] }
    _ => {
      let param = conv_expr_to_attrparam(env, expr)
      { name: "", params: [param] }
    }
  }
}

///|
fn conv_init_what(
  env : ConvEnv,
  typ : @cil.Typ,
  what : InitWhat,
) -> @cil.Offset {
  match what {
    NextInit => @cil.NoOffset
    InfieldInit(name, rest) =>
      match typ {
        @cil.TComp(ci, _) => {
          let mut result : @cil.Offset = @cil.NoOffset
          for fi in ci.cfields {
            if fi.fname == name {
              let rest_offset = conv_init_what(env, fi.ftype, rest)
              result = @cil.Field(fi, rest_offset)
              break
            }
          }
          result
        }
        _ => @cil.NoOffset
      }
    AtindexInit(idx_expr, rest) => {
      let (_, idx_exp, _) = conv_exp_impl(env, idx_expr, AExp)
      let elem_type = match typ {
        @cil.TArray(et, _, _) => et
        _ => @cil.TInt(@cil.IInt, [])
      }
      let rest_offset = conv_init_what(env, elem_type, rest)
      @cil.Index(idx_exp, rest_offset)
    }
    AtindexRangeInit(_, _) => @cil.NoOffset
  }
}

///|
fn conv_init(
  env : ConvEnv,
  typ : @cil.Typ,
  init_expr : InitExpression,
) -> @cil.Init? raise ConversionError {
  fn offset_eq(a : @cil.Offset, b : @cil.Offset) -> Bool {
    match (a, b) {
      (@cil.NoOffset, @cil.NoOffset) => true
      (@cil.Field(f1, r1), @cil.Field(f2, r2)) =>
        f1.fname == f2.fname && offset_eq(r1, r2)
      (@cil.Index(e1, r1), @cil.Index(e2, r2)) =>
        @cil.compare_exp(e1, e2) && offset_eq(r1, r2)
      _ => false
    }
  }

  fn offset_compose(outer : @cil.Offset, inner : @cil.Offset) -> @cil.Offset {
    match outer {
      @cil.NoOffset => inner
      @cil.Field(fi, rest) => @cil.Field(fi, offset_compose(rest, inner))
      @cil.Index(e, rest) => @cil.Index(e, offset_compose(rest, inner))
    }
  }

  fn array_len_const(len : @cil.Exp?) -> Int? {
    match len {
      Some(@cil.Const(@cil.CInt64(n, _, _))) =>
        if n < 0L {
          None
        } else {
          Some(n.to_int())
        }
      _ => None
    }
  }

  fn flatten_slots(t0 : @cil.Typ) -> Array[@cil.Offset] {
    // Match CIL's "subobject" stepping: NEXT_INIT advances by immediate fields/elements,
    // not by recursively flattening nested aggregates.
    let t = @cil.unroll_type(t0)
    match t {
      @cil.TComp(ci, _) =>
        if ci.cfields.is_empty() {
          []
        } else if not(ci.cstruct) {
          [@cil.Field(ci.cfields[0], @cil.NoOffset)]
        } else {
          ci.cfields.map(fn(fi) { @cil.Field(fi, @cil.NoOffset) })
        }
      @cil.TArray(_, len, _) =>
        match array_len_const(len) {
          Some(m) => {
            let slots : Array[@cil.Offset] = []
            let mut i = 0
            while i < m {
              slots.push(@cil.Index(@cil.integer(i), @cil.NoOffset))
              i = i + 1
            }
            slots
          }
          None => []
        }
      _ => [@cil.NoOffset]
    }
  }

  match init_expr {
    NoInit => None
    SingleInit(expr) => {
      let (_, exp, _) = conv_exp_impl(env, expr, AExp)
      Some(@cil.SingleInit(exp))
    }
    CompoundInit(inits) => {
      let cil_inits : Array[(@cil.Offset, @cil.Init)] = []
      let slots = flatten_slots(typ)
      let mut next = 0
      for init in inits {
        let (what, sub_init) = init
        let offset = match what {
          NextInit =>
            if next < slots.length() {
              let o = slots[next]
              next = next + 1
              o
            } else {
              @cil.NoOffset
            }
          _ => {
            let o = conv_init_what(env, typ, what)
            // advance the implicit cursor if possible
            let mut j = 0
            while j < slots.length() {
              if offset_eq(slots[j], o) {
                next = j + 1
                break
              }
              j = j + 1
            }
            o
          }
        }
        let sub_t = @cil.type_of_offset(typ, offset)
        let sub_cil_init = conv_init(env, sub_t, sub_init)
        match sub_cil_init {
          Some(i) => cil_inits.push((offset, i))
          None => ()
        }
      }
      // normalize nested inits: pull sub-offsets to the top-level offsets
      fn flatten_init_pairs(
        base_off : @cil.Offset,
        init : @cil.Init,
        out : Array[(@cil.Offset, @cil.Init)],
      ) -> Unit {
        match init {
          @cil.SingleInit(_) => out.push((base_off, init))
          @cil.CompoundInit(_, items) =>
            for item in items {
              let (off, sub) = item
              flatten_init_pairs(offset_compose(base_off, off), sub, out)
            }
        }
      }

      let normalized : Array[(@cil.Offset, @cil.Init)] = []
      for item in cil_inits {
        let (off, i) = item
        flatten_init_pairs(off, i, normalized)
      }
      Some(@cil.CompoundInit(typ, normalized))
    }
  }
}

///|
fn make_temp_var(
  env : ConvEnv,
  prefix : String,
  typ : @cil.Typ,
) -> @cil.VarInfo {
  let unique_name = "\{prefix}_\{env.temp_counter}"
  env.temp_counter = env.temp_counter + 1
  let vi : @cil.VarInfo = {
    vname: unique_name,
    vtype: typ,
    vattr: [],
    vstorage: @cil.NoStorage,
    vglob: false,
    vinline: false,
    vdecl: @cil.unknown_location,
    vinit: { init: None },
    vid: @cil.new_vid(),
    vaddrof: false,
    vreferenced: false,
    vdescr: "",
    vdescrpure: true,
  }
  env.locals.push(vi)
  vi
}

///|
fn offset_eq_for_local_init(a : @cil.Offset, b : @cil.Offset) -> Bool {
  match (a, b) {
    (@cil.NoOffset, @cil.NoOffset) => true
    (@cil.Field(f1, r1), @cil.Field(f2, r2)) =>
      f1.fname == f2.fname && offset_eq_for_local_init(r1, r2)
    (@cil.Index(e1, r1), @cil.Index(e2, r2)) =>
      @cil.compare_exp(e1, e2) && offset_eq_for_local_init(r1, r2)
    _ => false
  }
}

///|
fn offset_compose_for_local_init(
  outer : @cil.Offset,
  inner : @cil.Offset,
) -> @cil.Offset {
  match outer {
    @cil.NoOffset => inner
    @cil.Field(fi, rest) =>
      @cil.Field(fi, offset_compose_for_local_init(rest, inner))
    @cil.Index(e, rest) =>
      @cil.Index(e, offset_compose_for_local_init(rest, inner))
  }
}

///|
fn array_len_const_for_local_init(len : @cil.Exp?) -> Int? {
  match len {
    Some(@cil.Const(@cil.CInt64(n, _, _))) =>
      if n < 0L {
        None
      } else {
        Some(n.to_int())
      }
    _ => None
  }
}

///|
fn flatten_slots_for_local_init(t0 : @cil.Typ) -> Array[@cil.Offset] {
  let t = @cil.unroll_type(t0)
  match t {
    @cil.TComp(ci, _) =>
      if ci.cfields.is_empty() {
        []
      } else if not(ci.cstruct) {
        [@cil.Field(ci.cfields[0], @cil.NoOffset)]
      } else {
        ci.cfields.map(fn(fi) { @cil.Field(fi, @cil.NoOffset) })
      }
    @cil.TArray(_, len, _) =>
      match array_len_const_for_local_init(len) {
        Some(m) => {
          let slots : Array[@cil.Offset] = []
          let mut i = 0
          while i < m {
            let idx = @cil.integer(i)
            slots.push(@cil.Index(idx, @cil.NoOffset))
            i = i + 1
          }
          slots
        }
        None => []
      }
    _ => [@cil.NoOffset]
  }
}

///|
fn conv_local_init_to_instrs(
  env : ConvEnv,
  vi : @cil.VarInfo,
  root_type : @cil.Typ,
  target_off : @cil.Offset,
  init_expr : InitExpression,
  loc : @cil.Location,
) -> Array[@cil.Instr] raise ConversionError {
  let instrs : Array[@cil.Instr] = []
  let target_type = @cil.type_of_offset(root_type, target_off)
  match init_expr {
    NoInit => instrs
    SingleInit(e) => {
      let lv : @cil.LVal = { host: @cil.Var(vi), offset: target_off }
      let (set_instrs, _, _) = conv_exp_set(env, e, lv, target_type)
      instrs.append(set_instrs)
      instrs
    }
    CompoundInit(inits) => {
      let slots = flatten_slots_for_local_init(target_type)
      let mut next = 0
      for init in inits {
        let (what, sub_init) = init
        let rel_off = match what {
          NextInit =>
            if next < slots.length() {
              let o = slots[next]
              next = next + 1
              o
            } else {
              @cil.NoOffset
            }
          _ => {
            let o = conv_init_what(env, target_type, what)
            let mut j = 0
            while j < slots.length() {
              if offset_eq_for_local_init(slots[j], o) {
                next = j + 1
                break
              }
              j = j + 1
            }
            o
          }
        }
        let abs_off = offset_compose_for_local_init(target_off, rel_off)
        let sub_instrs = conv_local_init_to_instrs(
          env, vi, root_type, abs_off, sub_init, loc,
        )
        instrs.append(sub_instrs)
      }
      instrs
    }
  }
}

///|
pub fn conv_stmt(
  env : ConvEnv,
  s : CabsStatement,
) -> @cil.Stmt raise ConversionError {
  let loc = match s {
    Nop(l)
    | Computation(_, l)
    | Block(_, l)
    | If(_, _, _, l)
    | While(_, _, l)
    | DoWhile(_, _, l)
    | For(_, _, _, _, l)
    | Switch(_, _, l)
    | Case(_, _, l)
    | CaseRange(_, _, _, l)
    | Default(_, l)
    | Break(l)
    | Continue(l)
    | Return(_, l)
    | Goto(_, l)
    | CompGoto(_, l)
    | Label(_, _, l)
    | TryFinally(_, _, l)
    | TryExcept(_, _, _, l) => conv_loc(l)
    _ => @cil.unknown_location
  }
  match s {
    Nop(_) => @cil.mk_empty_stmt()
    Computation(e, _) => {
      let instrs = conv_exp_drop(env, e)
      @cil.mk_stmt(@cil.Instr(instrs))
    }
    Block(block, _) => {
      let stmts = block.bstmts.map(fn(s) { conv_stmt(env, s) })
      let blk : @cil.Block = {
        battrs: conv_block_attrs(env, block.battrs),
        bstmts: stmts,
      }
      @cil.mk_stmt(@cil.Block(blk))
    }
    If(cond, then_s, else_s, _) => {
      let (cond_instrs, cond_exp, _) = conv_exp(env, cond)
      let then_stmt = conv_stmt(env, then_s)
      let then_block : @cil.Block = { battrs: [], bstmts: [then_stmt] }
      let else_block : @cil.Block = match else_s {
        Nop(_) => { battrs: [], bstmts: [] }
        _ => {
          let else_stmt = conv_stmt(env, else_s)
          { battrs: [], bstmts: [else_stmt] }
        }
      }
      if cond_instrs.is_empty() {
        @cil.mk_stmt(@cil.If(cond_exp, then_block, else_block, loc))
      } else {
        let instr_stmt = @cil.mk_stmt(@cil.Instr(cond_instrs))
        let if_stmt = @cil.mk_stmt(
          @cil.If(cond_exp, then_block, else_block, loc),
        )
        let block : @cil.Block = { battrs: [], bstmts: [instr_stmt, if_stmt] }
        @cil.mk_stmt(@cil.Block(block))
      }
    }
    While(cond, body, _) => {
      let (cond_instrs, cond_exp, _) = conv_exp(env, cond)
      let body_stmt = conv_stmt(env, body)
      let is_const_true = match cond_exp {
        Const(CInt64(i, _, _)) => i != 0L
        _ => false
      }
      let loop_stmts = if is_const_true {
        if cond_instrs.is_empty() {
          [body_stmt]
        } else {
          let instr_stmt = @cil.mk_stmt(@cil.Instr(cond_instrs))
          [instr_stmt, body_stmt]
        }
      } else {
        let break_stmt = @cil.mk_stmt(@cil.Break(loc))
        let not_cond = @cil.UnOp(@cil.LNot, cond_exp, @cil.TInt(@cil.IInt, []))
        let break_block : @cil.Block = { battrs: [], bstmts: [break_stmt] }
        let empty_block : @cil.Block = { battrs: [], bstmts: [] }
        let cond_stmt = @cil.mk_stmt(
          @cil.If(not_cond, break_block, empty_block, loc),
        )
        if cond_instrs.is_empty() {
          [cond_stmt, body_stmt]
        } else {
          let instr_stmt = @cil.mk_stmt(@cil.Instr(cond_instrs))
          [instr_stmt, cond_stmt, body_stmt]
        }
      }
      let loop_block : @cil.Block = { battrs: [], bstmts: loop_stmts }
      @cil.mk_stmt(@cil.Loop(loop_block, loc, None, None))
    }
    For(init, cond, update, body, _) => {
      let init_stmts : Array[@cil.Stmt] = []
      match init {
        FcExp(e) => {
          let (instrs, _, _) = conv_exp(env, e)
          if not(instrs.is_empty()) {
            init_stmts.push(@cil.mk_stmt(@cil.Instr(instrs)))
          }
        }
        FcDecl(def) =>
          match def {
            DecDef(ing, _) => {
              let base_type = conv_type_specifier(env, ing.spec)
              for init_name in ing.init_names {
                let var_type = conv_decl_type(
                  env,
                  base_type,
                  init_name.name.decl_type,
                )
                let vi : @cil.VarInfo = {
                  vname: init_name.name.name,
                  vtype: var_type,
                  vattr: [],
                  vstorage: @cil.NoStorage,
                  vglob: false,
                  vinline: false,
                  vdecl: @cil.unknown_location,
                  vinit: { init: None },
                  vid: @cil.new_vid(),
                  vaddrof: false,
                  vreferenced: false,
                  vdescr: "",
                  vdescrpure: true,
                }
                env.locals.push(vi)
                env.env[vi.vname] = EnvVar(vi)
                match init_name.init {
                  NoInit => ()
                  SingleInit(e) => {
                    let lv : @cil.LVal = {
                      host: @cil.Var(vi),
                      offset: @cil.NoOffset,
                    }
                    let (right_instrs, _, _) = conv_exp_set(
                      env, e, lv, var_type,
                    )
                    if not(right_instrs.is_empty()) {
                      init_stmts.push(@cil.mk_stmt(@cil.Instr(right_instrs)))
                    }
                  }
                  _ => ()
                }
              }
            }
            _ => ()
          }
      }
      let (cond_instrs, cond_exp, _) = conv_exp(env, cond)
      let (update_instrs, _, _) = conv_exp(env, update)
      let body_stmt = conv_stmt(env, body)
      let break_stmt = @cil.mk_stmt(@cil.Break(loc))
      let not_cond = @cil.UnOp(@cil.LNot, cond_exp, @cil.TInt(@cil.IInt, []))
      let break_block : @cil.Block = { battrs: [], bstmts: [break_stmt] }
      let empty_block : @cil.Block = { battrs: [], bstmts: [] }
      let cond_stmt = @cil.mk_stmt(
        @cil.If(not_cond, break_block, empty_block, loc),
      )
      let update_stmt = @cil.mk_stmt(@cil.Instr(update_instrs))
      let loop_stmts = if cond_instrs.is_empty() {
        [cond_stmt, body_stmt, update_stmt]
      } else {
        let instr_stmt = @cil.mk_stmt(@cil.Instr(cond_instrs))
        [instr_stmt, cond_stmt, body_stmt, update_stmt]
      }
      let loop_block : @cil.Block = { battrs: [], bstmts: loop_stmts }
      let loop_stmt = @cil.mk_stmt(@cil.Loop(loop_block, loc, None, None))
      init_stmts.push(loop_stmt)
      let outer_block : @cil.Block = { battrs: [], bstmts: init_stmts }
      @cil.mk_stmt(@cil.Block(outer_block))
    }
    Switch(e, body, _) => {
      let (instrs, exp, _) = conv_exp(env, e)
      fn count_defaults(stmt : CabsStatement) -> Int {
        match stmt {
          Default(s, _) => 1 + count_defaults(s)
          Case(_, s, _) => count_defaults(s)
          CaseRange(_, _, s, _) => count_defaults(s)
          Label(_, s, _) => count_defaults(s)
          If(_, s1, s2, _) => count_defaults(s1) + count_defaults(s2)
          While(_, s, _) => count_defaults(s)
          DoWhile(_, s, _) => count_defaults(s)
          For(_, _, _, s, _) => count_defaults(s)
          Block(b, _) => {
            let mut n = 0
            for ss in b.bstmts {
              n = n + count_defaults(ss)
            }
            n
          }
          Switch(_, _, _) => 0
          _ => 0
        }
      }

      if count_defaults(body) > 1 {
        raise ConversionError("duplicate default")
      }
      let body_stmt = conv_stmt(env, body)
      let body_block : @cil.Block = { battrs: [], bstmts: [body_stmt] }
      if instrs.is_empty() {
        @cil.mk_stmt(@cil.Switch(exp, body_block, [], loc))
      } else {
        let instr_stmt = @cil.mk_stmt(@cil.Instr(instrs))
        let switch_stmt = @cil.mk_stmt(@cil.Switch(exp, body_block, [], loc))
        let block : @cil.Block = {
          battrs: [],
          bstmts: [instr_stmt, switch_stmt],
        }
        @cil.mk_stmt(@cil.Block(block))
      }
    }
    Case(e, body, _) => {
      // Try constant folding for case expression
      let exp = match eval_const_int64(env, e) {
        Some(v) => @cil.Const(@cil.CInt64(v, @cil.IInt, None))
        None => {
          let (_, exp, _) = conv_exp(env, e)
          exp
        }
      }
      let body_stmt = conv_stmt(env, body)
      body_stmt.labels.push(@cil.Case(exp, loc))
      body_stmt
    }
    Default(body, _) => {
      let body_stmt = conv_stmt(env, body)
      body_stmt.labels.push(@cil.Default(loc))
      body_stmt
    }
    Break(_) => @cil.mk_stmt(@cil.Break(loc))
    Continue(_) => @cil.mk_stmt(@cil.Continue(loc))
    Return(e, _) => {
      let ret_exp = match e {
        Nothing => None
        _ => {
          let (instrs, exp, _) = conv_exp(env, e)
          if instrs.is_empty() {
            Some(exp)
          } else {
            let instr_stmt = @cil.mk_stmt(@cil.Instr(instrs))
            let ret_stmt = @cil.mk_stmt(@cil.Return(Some(exp), loc))
            let blk : @cil.Block = {
              battrs: [],
              bstmts: [instr_stmt, ret_stmt],
            }
            return @cil.mk_stmt(@cil.Block(blk))
          }
        }
      }
      @cil.mk_stmt(@cil.Return(ret_exp, loc))
    }
    Goto(name, _) => {
      let goto_stmt = @cil.mk_stmt(@cil.Goto(@cil.mk_empty_stmt(), loc))
      env.gotos.push({ label_name: name, goto_stmt })
      goto_stmt
    }
    Label(name, body, _) => {
      let body_stmt = conv_stmt(env, body)
      body_stmt.labels.push(@cil.Label(name, loc, true))
      env.labels[name] = body_stmt
      body_stmt
    }
    StatDefinition(def) =>
      match def {
        DecDef(ing, dloc) => {
          let base_type = conv_type_specifier(env, ing.spec)
          let instrs : Array[@cil.Instr] = []
          for init_name in ing.init_names {
            let var_type0 = conv_decl_type(
              env,
              base_type,
              init_name.name.decl_type,
            )
            fn drop_const_attr(t : @cil.Typ) -> @cil.Typ {
              match t {
                @cil.TVoid(a) =>
                  @cil.TVoid(a.filter(fn(x) { x.name != "const" }))
                @cil.TInt(k, a) =>
                  @cil.TInt(k, a.filter(fn(x) { x.name != "const" }))
                @cil.TFloat(k, a) =>
                  @cil.TFloat(k, a.filter(fn(x) { x.name != "const" }))
                @cil.TPtr(bt, a) =>
                  @cil.TPtr(bt, a.filter(fn(x) { x.name != "const" }))
                @cil.TArray(bt, len, a) =>
                  @cil.TArray(bt, len, a.filter(fn(x) { x.name != "const" }))
                @cil.TFun(rt, ps, va, a) =>
                  @cil.TFun(rt, ps, va, a.filter(fn(x) { x.name != "const" }))
                @cil.TNamed(ti, a) =>
                  @cil.TNamed(ti, a.filter(fn(x) { x.name != "const" }))
                @cil.TComp(ci, a) =>
                  @cil.TComp(ci, a.filter(fn(x) { x.name != "const" }))
                @cil.TEnum(ei, a) =>
                  @cil.TEnum(ei, a.filter(fn(x) { x.name != "const" }))
                @cil.TBuiltinVaList(a) =>
                  @cil.TBuiltinVaList(a.filter(fn(x) { x.name != "const" }))
              }
            }

            let var_type = match init_name.init {
              SingleInit(_) => drop_const_attr(var_type0)
              _ => var_type0
            }
            let vi : @cil.VarInfo = {
              vname: init_name.name.name,
              vtype: var_type,
              vattr: conv_name_attrs(env, init_name.name.attrs),
              vstorage: @cil.NoStorage,
              vglob: false,
              vinline: false,
              vdecl: conv_loc(dloc),
              vinit: { init: None },
              vid: @cil.new_vid(),
              vaddrof: false,
              vreferenced: false,
              vdescr: "",
              vdescrpure: true,
            }
            env.locals.push(vi)
            env.env[init_name.name.name] = EnvVar(vi)
            match init_name.init {
              SingleInit(e) => {
                let lval : @cil.LVal = {
                  host: @cil.Var(vi),
                  offset: @cil.NoOffset,
                }
                let (init_instrs, _, _) = conv_exp_set(env, e, lval, var_type)
                instrs.append(init_instrs)
              }
              CompoundInit(_) => {
                let loc0 = conv_loc(dloc)
                let more = conv_local_init_to_instrs(
                  env,
                  vi,
                  var_type,
                  @cil.NoOffset,
                  init_name.init,
                  loc0,
                )
                instrs.append(more)
              }
              _ => ()
            }
          }
          if instrs.is_empty() {
            @cil.mk_empty_stmt()
          } else {
            @cil.mk_stmt(@cil.Instr(instrs))
          }
        }
        TypeDef(ng, _tloc) => {
          let base_type = conv_type_specifier(env, ng.spec)
          for name in ng.names {
            let full_type = conv_decl_type(env, base_type, name.decl_type)
            let ti : @cil.TypeInfo = {
              tname: name.name,
              ttype: full_type,
              treferenced: false,
            }
            env.env[name.name] = EnvTypeDef(ti)
          }
          @cil.mk_empty_stmt()
        }
        _ => @cil.mk_empty_stmt()
      }
    TryFinally(try_block, finally_block, _) => {
      let try_stmts = try_block.bstmts.map(fn(s) { conv_stmt(env, s) })
      let finally_stmts = finally_block.bstmts.map(fn(s) { conv_stmt(env, s) })
      let try_blk : @cil.Block = {
        battrs: conv_block_attrs(env, try_block.battrs),
        bstmts: try_stmts,
      }
      let finally_blk : @cil.Block = {
        battrs: conv_block_attrs(env, finally_block.battrs),
        bstmts: finally_stmts,
      }
      @cil.mk_stmt(@cil.TryFinally(try_blk, finally_blk, loc))
    }
    TryExcept(try_block, filter_expr, except_block, _) => {
      let try_stmts = try_block.bstmts.map(fn(s) { conv_stmt(env, s) })
      let try_blk : @cil.Block = {
        battrs: conv_block_attrs(env, try_block.battrs),
        bstmts: try_stmts,
      }
      let (filter_instrs, filter_exp, _) = conv_exp(env, filter_expr)
      let except_stmts = except_block.bstmts.map(fn(s) { conv_stmt(env, s) })
      let except_blk : @cil.Block = {
        battrs: conv_block_attrs(env, except_block.battrs),
        bstmts: except_stmts,
      }
      @cil.mk_stmt(
        @cil.TryExcept(try_blk, (filter_instrs, filter_exp), except_blk, loc),
      )
    }
    _ => @cil.mk_empty_stmt()
  }
}

///|
pub fn conv_fundec(
  env : ConvEnv,
  sn : SingleName,
  body : CabsBlock,
  loc : CabsLoc,
) -> @cil.FunDec raise ConversionError {
  let ret_type = conv_type_specifier(env, sn.spec)
  let full_type = conv_decl_type(env, ret_type, sn.name.decl_type)
  let params = match full_type {
    TFun(_, Some(ps), _, _) => ps
    _ => []
  }
  let func_var : @cil.VarInfo = {
    vname: sn.name.name,
    vtype: full_type,
    vattr: conv_name_attrs(env, sn.name.attrs),
    vstorage: @cil.NoStorage,
    vglob: true,
    vinline: false,
    vdecl: conv_loc(loc),
    vinit: { init: None },
    vid: @cil.new_vid(),
    vaddrof: false,
    vreferenced: false,
    vdescr: "",
    vdescrpure: true,
  }
  let local_env : Map[String, EnvEntry] = {}
  let remaining : Map[String, Int] = {}
  for p in params {
    let (n, _, _) = p
    if n.length() > 0 {
      let prev = remaining.get(n).unwrap_or(0)
      remaining[n] = prev + 1
    }
  }
  let formals : Array[@cil.VarInfo] = []
  for p in params {
    let (orig_name, typ, attrs) = p
    let mut printed_name = orig_name
    if orig_name.length() > 0 {
      let rem = remaining.get(orig_name).unwrap_or(0)
      if rem > 1 {
        printed_name = "\{orig_name}__\{(rem - 1).to_string()}"
      }
      remaining[orig_name] = rem - 1
    }
    let vi : @cil.VarInfo = {
      vname: printed_name,
      vtype: typ,
      vattr: attrs,
      vstorage: @cil.NoStorage,
      vglob: false,
      vinline: false,
      vdecl: @cil.unknown_location,
      vinit: { init: None },
      vid: @cil.new_vid(),
      vaddrof: false,
      vreferenced: false,
      vdescr: "",
      vdescrpure: true,
    }
    formals.push(vi)
    if orig_name.length() > 0 {
      if printed_name == orig_name {
        local_env[orig_name] = EnvVar(vi)
      } else {
        local_env[printed_name] = EnvVar(vi)
      }
    }
  }
  let local_comps : Map[String, @cil.CompInfo] = {}
  for k, v in env.comps {
    local_comps[k] = v
  }
  let new_env = {
    ..env,
    env: local_env,
    locals: [],
    labels: {},
    gotos: [],
    comps: local_comps,
  }
  let body_stmts = body.bstmts.map(fn(s) { conv_stmt(new_env, s) })
  resolve_gotos(new_env)
  let body_block : @cil.Block = {
    battrs: conv_block_attrs(env, body.battrs),
    bstmts: body_stmts,
  }
  {
    svar: func_var,
    sformals: formals,
    slocals: new_env.locals,
    smaxid: 0,
    sbody: body_block,
    smaxstmtid: None,
    sallstmts: [],
  }
}

///|
pub fn conv_global(
  env : ConvEnv,
  def : Definition,
) -> Array[@cil.Global] raise ConversionError {
  let globals : Array[@cil.Global] = []
  match def {
    FunDef(sn, body, loc, _) => {
      let fd = conv_fundec(env, sn, body, loc)
      env.genv[fd.svar.vname] = EnvVar(fd.svar)
      globals.push(@cil.GFun(fd, conv_loc(loc)))
    }
    DecDef(ing, loc) => {
      let base_type = conv_type_specifier(env, ing.spec)
      match base_type {
        TComp(ci, _) =>
          if ci.cname != "" && ci.cdefined && ci.cfields.length() > 0 {
            if not(env.emitted_comps.contains(ci.ckey)) {
              env.emitted_comps[ci.ckey] = true
              globals.push(@cil.GCompTag(ci, conv_loc(loc)))
            }
          }
        _ => ()
      }
      for init_name in ing.init_names {
        let var_type = conv_decl_type(env, base_type, init_name.name.decl_type)
        let vi : @cil.VarInfo = {
          vname: init_name.name.name,
          vtype: var_type,
          vattr: conv_name_attrs(env, init_name.name.attrs),
          vstorage: @cil.NoStorage,
          vglob: true,
          vinline: false,
          vdecl: conv_loc(loc),
          vinit: { init: None },
          vid: @cil.new_vid(),
          vaddrof: false,
          vreferenced: false,
          vdescr: "",
          vdescrpure: true,
        }
        env.genv[init_name.name.name] = EnvVar(vi)
        let var_name = init_name.name.name
        match init_name.init {
          NoInit =>
            if not(env.emitted_vars.contains(var_name)) {
              env.emitted_vars[var_name] = true
              globals.push(@cil.GVarDecl(vi, conv_loc(loc)))
            }
          _ => {
            env.emitted_vars[var_name] = true
            let cil_init = conv_init(env, var_type, init_name.init)
            let init_info : @cil.InitInfo = { init: cil_init }
            globals.push(@cil.GVar(vi, init_info, conv_loc(loc)))
          }
        }
      }
    }
    TypeDef(ng, loc) => {
      let base_type = conv_type_specifier(env, ng.spec)
      match base_type {
        @cil.TComp(ci, _) =>
          if ci.cname != "" &&
            ci.cdefined &&
            not(env.emitted_comps.contains(ci.ckey)) {
            env.emitted_comps[ci.ckey] = true
            globals.push(@cil.GCompTag(ci, conv_loc(loc)))
          }
        @cil.TEnum(ei, _) =>
          if ei.ename != "" &&
            ei.eitems.length() > 0 &&
            not(env.emitted_enums.contains(ei.ename)) {
            env.emitted_enums[ei.ename] = true
            globals.push(@cil.GEnumTag(ei, conv_loc(loc)))
          }
        _ => ()
      }
      for name in ng.names {
        let full_type = conv_decl_type(env, base_type, name.decl_type)
        let ti : @cil.TypeInfo = {
          tname: name.name,
          ttype: full_type,
          treferenced: false,
        }
        env.genv[name.name] = EnvTypeDef(ti)
        globals.push(@cil.GType(ti, conv_loc(loc)))
      }
    }
    OnlyTypeDef(spec, loc) => {
      let base_type = conv_type_specifier(env, spec)
      match base_type {
        @cil.TComp(ci, _) =>
          if ci.cname != "" &&
            ci.cdefined &&
            not(env.emitted_comps.contains(ci.ckey)) {
            env.emitted_comps[ci.ckey] = true
            globals.push(@cil.GCompTag(ci, conv_loc(loc)))
          }
        @cil.TEnum(ei, _) =>
          if ei.ename != "" &&
            ei.eitems.length() > 0 &&
            not(env.emitted_enums.contains(ei.ename)) {
            env.emitted_enums[ei.ename] = true
            globals.push(@cil.GEnumTag(ei, conv_loc(loc)))
          }
        _ => ()
      }
    }
    GlobAsm(s, loc) => globals.push(@cil.GAsm(s, conv_loc(loc)))
    Pragma(expr, loc) => {
      let attr = conv_expr_to_attr(env, expr)
      globals.push(@cil.GPragma(attr, conv_loc(loc)))
    }
    Linkage(_, _, defs) =>
      for inner_def in defs {
        globals.append(conv_global(env, inner_def))
      }
    Transformer(_, _, loc) =>
      raise ConversionError(
        "TRANSFORMER should not appear in cabs2cil input at \{loc}",
      )
    ExprTransformer(_, _, loc) =>
      raise ConversionError(
        "EXPRTRANSFORMER should not appear in cabs2cil input at \{loc}",
      )
  }
  globals
}

///|
pub fn conv_file(cabs : CabsFile) -> @cil.File raise ConversionError {
  let env = ConvEnv::new(cabs.filename)
  fn spec_has_inline_and_extern(spec : Specifier) -> Bool {
    let Specifier(items) = spec
    let mut has_inline = false
    let mut has_extern = false
    for it in items {
      match it {
        SpecInline => has_inline = true
        SpecStorage(Extern) => has_extern = true
        _ => ()
      }
    }
    has_inline && has_extern
  }

  let extinline_bases : Map[String, Bool] = {}
  for def in cabs.definitions {
    match def {
      FunDef(sn, _, _, _) => {
        let n = sn.name.name
        if n.has_suffix("__extinline") {
          let base = (n[0:n.length() - "__extinline".length()] catch {
            _ => ""
          }).to_string()
          if base.length() > 0 {
            extinline_bases[base] = true
          }
        }
      }
      _ => ()
    }
  }
  let globals : Array[@cil.Global] = []
  for def in cabs.definitions {
    match def {
      FunDef(sn, _, loc, _) => {
        let n = sn.name.name
        if not(n.has_suffix("__extinline")) &&
          extinline_bases.contains(n) &&
          spec_has_inline_and_extern(sn.spec) {
          raise ConversionError("Trying to rename at \{loc}")
        }
      }
      _ => ()
    }
    let gs = conv_global(env, def)
    globals.append(gs)
  }
  { filename: cabs.filename, globals, globinit: None, globinitcalled: false }
}

///|
pub fn parse_and_convert(
  source : String,
  filename : String,
) -> @cil.File raise ConversionError {
  let cabs = parse_c_source(source, filename) catch {
    ParseError(msg) => raise ConversionError("Parse error: \{msg}")
  }
  conv_file(cabs)
}

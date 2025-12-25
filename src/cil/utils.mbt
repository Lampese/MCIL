///|
pub fn compare_loc(l1 : Location, l2 : Location) -> Int {
  let file_cmp = l1.file.compare(l2.file)
  if file_cmp != 0 {
    file_cmp
  } else {
    let line_cmp = l1.line - l2.line
    if line_cmp != 0 {
      line_cmp
    } else {
      l1.byte - l2.byte
    }
  }
}

///|
pub fn void_type() -> Typ {
  TVoid([])
}

///|
pub fn int_type() -> Typ {
  TInt(IInt, [])
}

///|
pub fn uint_type() -> Typ {
  TInt(IUInt, [])
}

///|
pub fn long_type() -> Typ {
  TInt(ILong, [])
}

///|
pub fn ulong_type() -> Typ {
  TInt(IULong, [])
}

///|
pub fn char_type() -> Typ {
  TInt(IChar, [])
}

///|
pub fn double_type() -> Typ {
  TFloat(FDouble, [])
}

///|
pub fn float_type() -> Typ {
  TFloat(FFloat, [])
}

///|
pub fn char_ptr_type() -> Typ {
  TPtr(char_type(), [])
}

///|
pub fn void_ptr_type() -> Typ {
  TPtr(void_type(), [])
}

///|
pub fn int_ptr_type() -> Typ {
  TPtr(int_type(), [])
}

///|
pub fn is_integral_type(t : Typ) -> Bool {
  match t {
    TInt(_, _) => true
    TEnum(_, _) => true
    _ => false
  }
}

///|
pub fn is_floating_type(t : Typ) -> Bool {
  match t {
    TFloat(_, _) => true
    _ => false
  }
}

///|
pub fn is_float_type(t : Typ) -> Bool {
  is_floating_type(t)
}

///|
pub fn is_arithmetic_type(t : Typ) -> Bool {
  is_integral_type(t) || is_floating_type(t)
}

///|
pub fn is_pointer_type(t : Typ) -> Bool {
  match t {
    TPtr(_, _) => true
    _ => false
  }
}

///|
pub fn is_array_type(t : Typ) -> Bool {
  match t {
    TArray(_, _, _) => true
    _ => false
  }
}

///|
pub fn is_function_type(t : Typ) -> Bool {
  match t {
    TFun(_, _, _, _) => true
    _ => false
  }
}

///|
pub fn is_scalar_type(t : Typ) -> Bool {
  is_arithmetic_type(t) || is_pointer_type(t)
}

///|
pub fn unroll_type(t : Typ) -> Typ {
  match t {
    TNamed(ti, _) => unroll_type(ti.ttype)
    _ => t
  }
}

///|
pub fn zero() -> Exp {
  Const(CInt64(0L, IInt, None))
}

///|
pub fn one() -> Exp {
  Const(CInt64(1L, IInt, None))
}

///|
pub fn mone() -> Exp {
  Const(CInt64(-1L, IInt, None))
}

///|
pub fn integer(i : Int) -> Exp {
  Const(CInt64(i.to_int64(), IInt, None))
}

///|
pub fn kinteger64(k : IKind, i : Int64) -> Exp {
  Const(CInt64(i, k, None))
}

///|
pub fn mk_string(s : String) -> Exp {
  Const(CStr(s))
}

///|
pub fn is_constant(e : Exp) -> Bool {
  match e {
    Const(_) => true
    _ => false
  }
}

///|
pub fn is_integer(e : Exp) -> Int64? {
  match e {
    Const(CInt64(n, _, _)) => Some(n)
    _ => None
  }
}

///|
pub fn is_zero(e : Exp) -> Bool {
  match e {
    Const(CInt64(0L, _, _)) => true
    _ => false
  }
}

///|
pub fn mk_var(vi : VarInfo) -> LVal {
  { host: Var(vi), offset: NoOffset }
}

///|
pub fn mk_mem(addr : Exp, off : Offset) -> LVal {
  match (addr, off) {
    (AddrOf(lv), NoOffset) => lv
    _ => { host: Mem(addr), offset: off }
  }
}

///|
pub fn add_offset_lval(lv : LVal, off : Offset) -> LVal {
  { host: lv.host, offset: add_offset(lv.offset, off) }
}

///|
pub fn add_offset(base : Offset, extra : Offset) -> Offset {
  match base {
    NoOffset => extra
    Field(fi, rest) => Field(fi, add_offset(rest, extra))
    Index(e, rest) => Index(e, add_offset(rest, extra))
  }
}

///|
let next_sid : Ref[Int] = Ref::new(0)

///|
pub fn new_sid() -> Int {
  let id = next_sid.val
  next_sid.val = id + 1
  id
}

///|
pub fn mk_stmt(kind : StmtKind) -> Stmt {
  { labels: [], skind: kind, sid: new_sid(), succs: [], preds: [] }
}

///|
pub fn mk_empty_stmt() -> Stmt {
  mk_stmt(Instr([]))
}

///|
pub fn mk_block(stmts : Array[Stmt]) -> Block {
  { battrs: [], bstmts: stmts }
}

///|
let next_vid : Ref[Int] = Ref::new(0)

///|
pub fn new_vid() -> Int {
  let id = next_vid.val
  next_vid.val = id + 1
  id
}

///|
let next_comp_key : Ref[Int] = Ref::new(0)

///|
pub fn new_comp_key() -> Int {
  let id = next_comp_key.val
  next_comp_key.val = id + 1
  id
}

///|
pub fn make_global_var(name : String, t : Typ) -> VarInfo {
  {
    vname: name,
    vtype: t,
    vattr: [],
    vstorage: NoStorage,
    vglob: true,
    vinline: false,
    vdecl: unknown_location,
    vinit: { init: None },
    vid: new_vid(),
    vaddrof: false,
    vreferenced: false,
    vdescr: "",
    vdescrpure: true,
  }
}

///|
pub fn make_local_var(name : String, t : Typ) -> VarInfo {
  {
    vname: name,
    vtype: t,
    vattr: [],
    vstorage: NoStorage,
    vglob: false,
    vinline: false,
    vdecl: unknown_location,
    vinit: { init: None },
    vid: new_vid(),
    vaddrof: false,
    vreferenced: false,
    vdescr: "",
    vdescrpure: true,
  }
}

///|
pub fn make_temp_var(f : FunDec, name : String, t : Typ) -> VarInfo {
  let vi = make_local_var(name, t)
  f.slocals.push(vi)
  vi
}

///|
pub fn empty_file(name : String) -> File {
  { filename: name, globals: [], globinit: None, globinitcalled: false }
}

///|
pub fn iter_globals(f : File, action : (Global) -> Unit) -> Unit {
  for g in f.globals {
    action(g)
  }
}

///|
pub fn[A] fold_globals(f : File, init : A, action : (A, Global) -> A) -> A {
  let mut acc = init
  for g in f.globals {
    acc = action(acc, g)
  }
  acc
}

///|
pub let unknown_loc : Location = { file: "<unknown>", line: -1, byte: -1 }

///|
pub fn type_of(e : Exp) -> Typ {
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
    Lval(lv) => type_of_lval(lv)
    SizeOf(_) => uint_type()
    SizeOfE(_) => uint_type()
    SizeOfStr(_) => uint_type()
    AlignOf(_) => uint_type()
    AlignOfE(_) => uint_type()
    UnOp(_, _, t) => t
    BinOp(_, _, _, t) => t
    Question(_, e2, _, _) => type_of(e2)
    CastE(t, _) => t
    AddrOf(lv) => TPtr(type_of_lval(lv), [])
    AddrOfLabel(_) => TPtr(TVoid([]), [])
    StartOf(lv) =>
      match type_of_lval(lv) {
        TArray(t, _, _) => TPtr(t, [])
        t => t
      }
  }
}

///|
pub fn type_of_lval(lv : LVal) -> Typ {
  let base_type = match lv.host {
    Var(vi) => vi.vtype
    Mem(e) =>
      match type_of(e) {
        TPtr(t, _) => t
        _ => TVoid([])
      }
  }
  type_of_offset(base_type, lv.offset)
}

///|
pub fn type_of_offset(base : Typ, off : Offset) -> Typ {
  match off {
    NoOffset => base
    Field(fi, rest) => type_of_offset(fi.ftype, rest)
    Index(_, rest) =>
      match unroll_type(base) {
        TArray(elem, _, _) => type_of_offset(elem, rest)
        _ => base
      }
  }
}

///|
pub(all) struct Location {
  line : Int
  file : String
  byte : Int
}

///|
pub let unknown_location : Location = { line: -1, file: "", byte: 0 }

///|
pub(all) enum IKind {
  IChar
  ISChar
  IUChar
  IBool
  IInt
  IUInt
  IShort
  IUShort
  ILong
  IULong
  ILongLong
  IULongLong
} derive(Eq)

///|
pub(all) enum FKind {
  FFloat
  FDouble
  FLongDouble
} derive(Eq)

///|
pub(all) enum Storage {
  NoStorage
  Static
  Register
  Extern
}

///|
pub(all) struct Attribute {
  name : String
  params : Array[AttrParam]
}

///|
pub(all) enum AttrParam {
  AInt(Int)
  AStr(String)
  ACons(String, Array[AttrParam])
  ASizeOf(Typ)
  ASizeOfE(AttrParam)
  AAlignOf(Typ)
  AAlignOfE(AttrParam)
  AUnOp(UnOp, AttrParam)
  ABinOp(BinOp, AttrParam, AttrParam)
  ADot(AttrParam, String)
  AStar(AttrParam)
  AAddrOf(AttrParam)
  AIndex(AttrParam, AttrParam)
  AQuestion(AttrParam, AttrParam, AttrParam)
}

///|
pub(all) struct TypeInfo {
  tname : String
  ttype : Typ
  treferenced : Bool
}

///|
pub(all) struct EnumInfo {
  ename : String
  eitems : Array[(String, Exp, Location)]
  eattr : Array[Attribute]
  ereferenced : Bool
  ekind : IKind
}

///|
pub(all) struct CompInfo {
  cstruct : Bool
  cname : String
  ckey : Int
  cfields : Array[FieldInfo]
  cattr : Array[Attribute]
  mut cdefined : Bool
  creferenced : Bool
}

///|
pub(all) struct FieldInfo {
  fcomp : CompInfo
  fname : String
  ftype : Typ
  fbitfield : Int?
  fattr : Array[Attribute]
  floc : Location
}

///|
pub(all) enum Typ {
  TVoid(Array[Attribute])
  TInt(IKind, Array[Attribute])
  TFloat(FKind, Array[Attribute])
  TPtr(Typ, Array[Attribute])
  TArray(Typ, Exp?, Array[Attribute])
  TFun(Typ, Array[(String, Typ, Array[Attribute])]?, Bool, Array[Attribute])
  TNamed(TypeInfo, Array[Attribute])
  TComp(CompInfo, Array[Attribute])
  TEnum(EnumInfo, Array[Attribute])
  TBuiltinVaList(Array[Attribute])
}

///|
pub(all) enum UnOp {
  Neg
  BNot
  LNot
}

///|
pub(all) enum BinOp {
  PlusA
  PlusPI
  IndexPI
  MinusA
  MinusPI
  MinusPP
  Mult
  Div
  Mod
  Shiftlt
  Shiftrt
  Lt
  Gt
  Le
  Ge
  Eq
  Ne
  BAnd
  BXor
  BOr
  LAnd
  LOr
}

///|
pub(all) enum Constant {
  CInt64(Int64, IKind, String?)
  CStr(String)
  CWStr(Array[Int64])
  CChr(Char)
  CReal(Double, FKind, String?)
  CEnum(Exp, String, EnumInfo)
}

///|
pub(all) enum LHost {
  Var(VarInfo)
  Mem(Exp)
}

///|
pub(all) enum Offset {
  NoOffset
  Field(FieldInfo, Offset)
  Index(Exp, Offset)
}

///|
pub(all) struct LVal {
  host : LHost
  offset : Offset
}

///|
pub(all) enum Exp {
  Const(Constant)
  Lval(LVal)
  SizeOf(Typ)
  SizeOfE(Exp)
  SizeOfStr(String)
  AlignOf(Typ)
  AlignOfE(Exp)
  UnOp(UnOp, Exp, Typ)
  BinOp(BinOp, Exp, Exp, Typ)
  Question(Exp, Exp, Exp, Typ)
  CastE(Typ, Exp)
  AddrOf(LVal)
  AddrOfLabel(Stmt)
  StartOf(LVal)
}

///|
pub(all) struct VarInfo {
  vname : String
  vtype : Typ
  vattr : Array[Attribute]
  vstorage : Storage
  vglob : Bool
  vinline : Bool
  vdecl : Location
  vinit : InitInfo
  vid : Int
  vaddrof : Bool
  vreferenced : Bool
  vdescr : String
  vdescrpure : Bool
}

///|
pub(all) struct InitInfo {
  init : Init?
}

///|
pub(all) enum Init {
  SingleInit(Exp)
  CompoundInit(Typ, Array[(Offset, Init)])
}

///|
pub(all) enum Label {
  Label(String, Location, Bool)
  Case(Exp, Location)
  CaseRange(Exp, Exp, Location)
  Default(Location)
}

///|
pub(all) enum StmtKind {
  Instr(Array[Instr])
  Return(Exp?, Location)
  Goto(Stmt, Location)
  ComputedGoto(Exp, Location)
  Break(Location)
  Continue(Location)
  If(Exp, Block, Block, Location)
  Switch(Exp, Block, Array[Stmt], Location)
  Loop(Block, Location, Stmt?, Stmt?)
  Block(Block)
  TryFinally(Block, Block, Location)
  TryExcept(Block, (Array[Instr], Exp), Block, Location)
}

///|
pub(all) struct Stmt {
  labels : Array[Label]
  mut skind : StmtKind
  sid : Int
  succs : Array[Stmt]
  preds : Array[Stmt]
}

///|
pub(all) enum Instr {
  Set(LVal, Exp, Location)
  Call(LVal?, Exp, Array[Exp], Location)
  Asm(
    Array[Attribute],
    Array[String],
    Array[(String?, String, LVal)],
    Array[(String?, String, Exp)],
    Array[String],
    Location
  )
}

///|
pub(all) struct Block {
  battrs : Array[Attribute]
  bstmts : Array[Stmt]
}

///|
pub(all) struct FunDec {
  svar : VarInfo
  sformals : Array[VarInfo]
  slocals : Array[VarInfo]
  smaxid : Int
  mut sbody : Block
  smaxstmtid : Int?
  sallstmts : Array[Stmt]
}

///|
pub(all) enum Global {
  GType(TypeInfo, Location)
  GCompTag(CompInfo, Location)
  GCompTagDecl(CompInfo, Location)
  GEnumTag(EnumInfo, Location)
  GEnumTagDecl(EnumInfo, Location)
  GVarDecl(VarInfo, Location)
  GVar(VarInfo, InitInfo, Location)
  GFun(FunDec, Location)
  GAsm(String, Location)
  GPragma(Attribute, Location)
  GText(String)
}

///|
pub(all) struct Comment {
  loc : Location
  text : String
}

///|
pub(all) struct File {
  filename : String
  globals : Array[Global]
  globinit : FunDec?
  globinitcalled : Bool
}

///|
pub struct CabsLoc {
  lineno : Int
  filename : String
  byteno : Int
  ident : Int
} derive(Show)

///|
pub enum TypeSpecifier {
  Tvoid
  Tchar
  Tbool
  Tshort
  Tint
  Tlong
  Tint64
  Tfloat
  Tdouble
  Tsigned
  Tunsigned
  Tnamed(String)
  Tstruct(String, Array[FieldGroup]?, Array[CabsAttribute])
  Tunion(String, Array[FieldGroup]?, Array[CabsAttribute])
  Tenum(String, Array[EnumItem]?, Array[CabsAttribute])
  TtypeofE(CabsExpression)
  TtypeofT(Specifier, DeclType)
} derive(Show)

///|
pub enum CabsStorage {
  Auto
  Static
  Extern
  Register
} derive(Show)

///|
pub enum CVSpec {
  CvConst
  CvVolatile
  CvRestrict
} derive(Show)

///|
pub enum SpecElem {
  SpecTypedef
  SpecCV(CVSpec)
  SpecAttr(CabsAttribute)
  SpecStorage(CabsStorage)
  SpecInline
  SpecType(TypeSpecifier)
  SpecPattern(String)
} derive(Show)

///|
pub struct Specifier(Array[SpecElem]) derive(Show)

///|
pub enum DeclType {
  JustBase
  ParenType(Array[CabsAttribute], DeclType, Array[CabsAttribute])
  Array(DeclType, Array[CabsAttribute], CabsExpression)
  Ptr(Array[CabsAttribute], DeclType)
  Proto(DeclType, Array[SingleName], Bool)
} derive(Show)

///|
pub struct NameGroup {
  spec : Specifier
  names : Array[Name]
} derive(Show)

///|
pub struct FieldGroup {
  spec : Specifier
  fields : Array[(Name, CabsExpression?)]
} derive(Show)

///|
pub struct InitNameGroup {
  spec : Specifier
  init_names : Array[InitName]
} derive(Show)

///|
pub struct Name {
  name : String
  decl_type : DeclType
  attrs : Array[CabsAttribute]
  loc : CabsLoc
} derive(Show)

///|
pub struct InitName {
  name : Name
  init : InitExpression
} derive(Show)

///|
pub struct SingleName {
  spec : Specifier
  name : Name
} derive(Show)

///|
pub struct EnumItem {
  name : String
  value : CabsExpression
  loc : CabsLoc
} derive(Show)

///|
pub enum Definition {
  FunDef(SingleName, CabsBlock, CabsLoc, CabsLoc)
  DecDef(InitNameGroup, CabsLoc)
  TypeDef(NameGroup, CabsLoc)
  OnlyTypeDef(Specifier, CabsLoc)
  GlobAsm(String, CabsLoc)
  Pragma(CabsExpression, CabsLoc)
  Linkage(String, CabsLoc, Array[Definition])
  Transformer(Definition, Array[Definition], CabsLoc)
  ExprTransformer(CabsExpression, CabsExpression, CabsLoc)
} derive(Show)

///|
pub struct CabsFile {
  filename : String
  definitions : Array[Definition]
} derive(Show)

///|
pub struct CabsBlock {
  blabels : Array[String]
  battrs : Array[CabsAttribute]
  bstmts : Array[CabsStatement]
} derive(Show)

///|
pub struct AsmDetails {
  aoutputs : Array[(String?, String, CabsExpression)]
  ainputs : Array[(String?, String, CabsExpression)]
  aclobbers : Array[String]
} derive(Show)

///|
pub enum ForClause {
  FcExp(CabsExpression)
  FcDecl(Definition)
} derive(Show)

///|
pub enum CabsStatement {
  Nop(CabsLoc)
  Computation(CabsExpression, CabsLoc)
  Block(CabsBlock, CabsLoc)
  If(CabsExpression, CabsStatement, CabsStatement, CabsLoc)
  While(CabsExpression, CabsStatement, CabsLoc)
  DoWhile(CabsExpression, CabsStatement, CabsLoc)
  For(ForClause, CabsExpression, CabsExpression, CabsStatement, CabsLoc)
  Break(CabsLoc)
  Continue(CabsLoc)
  Return(CabsExpression, CabsLoc)
  Switch(CabsExpression, CabsStatement, CabsLoc)
  Case(CabsExpression, CabsStatement, CabsLoc)
  CaseRange(CabsExpression, CabsExpression, CabsStatement, CabsLoc)
  Default(CabsStatement, CabsLoc)
  Label(String, CabsStatement, CabsLoc)
  Goto(String, CabsLoc)
  CompGoto(CabsExpression, CabsLoc)
  StatDefinition(Definition)
  Asm(Array[CabsAttribute], Array[String], AsmDetails?, CabsLoc)
  TryExcept(CabsBlock, CabsExpression, CabsBlock, CabsLoc)
  TryFinally(CabsBlock, CabsBlock, CabsLoc)
} derive(Show)

///|
pub enum CabsBinaryOp {
  Add
  Sub
  Mul
  Div
  Mod
  And
  Or
  Band
  Bor
  Xor
  Shl
  Shr
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
  Assign
  AddAssign
  SubAssign
  MulAssign
  DivAssign
  ModAssign
  BandAssign
  BorAssign
  XorAssign
  ShlAssign
  ShrAssign
} derive(Show)

///|
pub enum CabsUnaryOp {
  Minus
  Plus
  Not
  Bnot
  Memof
  Addrof
  Preincr
  Predecr
  Posincr
  Posdecr
} derive(Show)

///|
pub enum CabsExpression {
  Nothing
  Unary(CabsUnaryOp, CabsExpression)
  LabelAddr(String)
  Binary(CabsBinaryOp, CabsExpression, CabsExpression)
  Question(CabsExpression, CabsExpression, CabsExpression)
  Cast((Specifier, DeclType), InitExpression)
  Call(CabsExpression, Array[CabsExpression])
  Comma(Array[CabsExpression])
  Constant(CabsConstant)
  Paren(CabsExpression)
  Variable(String)
  ExprSizeof(CabsExpression)
  TypeSizeof(Specifier, DeclType)
  ExprAlignof(CabsExpression)
  TypeAlignof(Specifier, DeclType)
  Index(CabsExpression, CabsExpression)
  MemberOf(CabsExpression, String)
  MemberOfPtr(CabsExpression, String)
  GnuBody(CabsBlock)
  ExprPattern(String)
} derive(Show)

///|
pub enum CabsConstant {
  ConstInt(String)
  ConstFloat(String)
  ConstChar(Array[Int64])
  ConstWchar(Array[Int64])
  ConstString(String)
  ConstWstring(Array[Int64])
} derive(Show)

///|
pub enum InitExpression {
  NoInit
  SingleInit(CabsExpression)
  CompoundInit(Array[(InitWhat, InitExpression)])
} derive(Show)

///|
pub enum InitWhat {
  NextInit
  InfieldInit(String, InitWhat)
  AtindexInit(CabsExpression, InitWhat)
  AtindexRangeInit(CabsExpression, CabsExpression)
} derive(Show)

///|
pub struct CabsAttribute {
  name : String
  args : Array[CabsExpression]
} derive(Show)

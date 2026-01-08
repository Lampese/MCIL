///|
pub enum Token {
  Ident(String)
  NamedType(String)
  IntConst(String)
  FloatConst(String)
  StringConst(String)
  CharConst(String)
  WideStringConst(String)
  WideCharConst(String)
  KwAuto
  KwBreak
  KwCase
  KwChar
  KwConst
  KwContinue
  KwDefault
  KwDo
  KwDouble
  KwElse
  KwEnum
  KwExtern
  KwFloat
  KwFor
  KwGoto
  KwIf
  KwInline
  KwInt
  KwLong
  KwRegister
  KwRestrict
  KwReturn
  KwShort
  KwSigned
  KwSizeof
  KwStatic
  KwStruct
  KwSwitch
  KwTypedef
  KwUnion
  KwUnsigned
  KwVoid
  KwVolatile
  KwWhile
  KwBool
  KwComplex
  KwImaginary
  KwAlignof
  KwAlignAs
  KwAtomic
  KwGeneric
  KwNoreturn
  KwStaticAssert
  KwAsm
  KwPragma
  KwAttribute
  KwTypeof
  KwExtension
  KwBuiltinVaArg
  KwBuiltinVaList
  KwBuiltinOffsetof
  KwBuiltinTypesCompat
  KwFunctionName
  KwPrettyFunctionName
  KwLabel
  KwThread
  KwInt128(String)
  KwDeclspec
  KwInt64
  KwMsAttr(String)
  KwTry
  KwExcept
  KwFinally
  KwBlockAttribute
  KwNullability(String)
  KwCcuredAttr(String)
  // CIL patch system tokens
  AtTransform
  AtTransformExpr
  AtSpecifier
  AtExpr
  AtName
  Plus
  Minus
  Star
  Slash
  Percent
  Amp
  Pipe
  Caret
  Tilde
  Bang
  Eq
  Lt
  Gt
  Question
  Colon
  Dot
  Comma
  Semi
  PlusPlus
  MinusMinus
  Arrow
  LtLt
  GtGt
  LtEq
  GtEq
  EqEq
  BangEq
  AmpAmp
  PipePipe
  PlusEq
  MinusEq
  StarEq
  SlashEq
  PercentEq
  AmpEq
  PipeEq
  CaretEq
  LtLtEq
  GtGtEq
  Ellipsis
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  Eof
  Hash
  HashHash
} derive(Show)

///|
enum NameKind {
  TypeName
  Identifier
}

///|
pub struct LexerContext {
  lexicon : Map[String, NameKind]
  scope_stack : Array[Array[(String, NameKind?)]]
}

///|
pub fn LexerContext::new() -> LexerContext {
  let ctx : LexerContext = { lexicon: {}, scope_stack: [[]] }
  ctx.lexicon["__builtin_va_list"] = TypeName
  ctx
}

///|
pub fn LexerContext::add_type(self : LexerContext, name : String) -> Unit {
  match self.scope_stack.last() {
    Some(scope) => {
      let prev = self.lexicon.get(name)
      scope.push((name, prev))
    }
    None => ()
  }
  self.lexicon[name] = TypeName
}

///|
pub fn LexerContext::add_identifier(self : LexerContext, name : String) -> Unit {
  match self.scope_stack.last() {
    Some(scope) => {
      let prev = self.lexicon.get(name)
      scope.push((name, prev))
    }
    None => ()
  }
  self.lexicon[name] = Identifier
}

///|
pub fn LexerContext::push_context(self : LexerContext) -> Unit {
  self.scope_stack.push([])
}

///|
pub fn LexerContext::pop_context(self : LexerContext) -> Unit {
  match self.scope_stack.pop() {
    Some(entries) =>
      for i = entries.length() - 1; i >= 0; i = i - 1 {
        let (name, prev) = entries[i]
        match prev {
          Some(kind) => self.lexicon[name] = kind
          None => self.lexicon.remove(name)
        }
      }
    None => ()
  }
}

///|
pub fn LexerContext::is_type_name(self : LexerContext, name : String) -> Bool {
  match self.lexicon.get(name) {
    Some(TypeName) => true
    _ => false
  }
}

///|
pub struct Lexer {
  source : String
  mut pos : Int
  mut line : Int
  mut col : Int
  filename : String
  context : LexerContext
}

///|
pub fn Lexer::new(source : String, filename : String) -> Lexer {
  { source, pos: 0, line: 1, col: 1, filename, context: LexerContext::new() }
}

///|
pub fn Lexer::with_context(
  source : String,
  filename : String,
  context : LexerContext,
) -> Lexer {
  { source, pos: 0, line: 1, col: 1, filename, context }
}

///|
fn Lexer::is_eof(self : Lexer) -> Bool {
  self.pos >= self.source.length()
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.is_eof() {
    '\u{00}'
  } else {
    self.source[self.pos].to_char().unwrap()
  }
}

///|
fn Lexer::peek_next(self : Lexer) -> Char {
  if self.pos + 1 >= self.source.length() {
    '\u{00}'
  } else {
    self.source[self.pos + 1].to_char().unwrap()
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos = self.pos + 1
  if c == '\n' {
    self.line = self.line + 1
    self.col = 1
  } else {
    self.col = self.col + 1
  }
  c
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while not(self.is_eof()) {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      let _ = self.advance()

    } else if c == '#' {
      while not(self.is_eof()) && self.peek() != '\n' {
        let _ = self.advance()

      }
    } else if c == '/' && self.peek_next() == '/' {
      while not(self.is_eof()) && self.peek() != '\n' {
        let _ = self.advance()

      }
    } else if c == '/' && self.peek_next() == '*' {
      let _ = self.advance()
      let _ = self.advance()
      while not(self.is_eof()) {
        if self.peek() == '*' && self.peek_next() == '/' {
          let _ = self.advance()
          let _ = self.advance()
          break
        }
        let _ = self.advance()

      }
    } else {
      break
    }
  }
}

///|
fn is_ident_start(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '_' | '$')
}

///|
fn is_ident_char(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c)
}

///|
fn is_digit(c : Char) -> Bool {
  c is ('0'..='9')
}

///|
fn is_alpha_or_underscore(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '_')
}

///|
fn is_hex_digit(c : Char) -> Bool {
  is_digit(c) || c is ('a'..='f' | 'A'..='F')
}

///|
fn Lexer::read_identifier(self : Lexer) -> Token {
  let start = self.pos
  while not(self.is_eof()) && is_ident_char(self.peek()) {
    let _ = self.advance()

  }
  let text = try! self.source[start:self.pos]
  if text == "__pragma" {
    self.skip_whitespace()
    if self.peek() == '(' {
      let _ = self.advance()
      let mut depth = 1
      while depth > 0 && not(self.is_eof()) {
        let c = self.peek()
        let _ = self.advance()
        if c == '(' {
          depth = depth + 1
        } else if c == ')' {
          depth = depth - 1
        }
      }
    }
    return self.next_token()
  }
  match text {
    "auto" => KwAuto
    "break" => KwBreak
    "case" => KwCase
    "char" => KwChar
    "const" | "__const" | "__const__" => KwConst
    "continue" => KwContinue
    "default" => KwDefault
    "do" => KwDo
    "double" => KwDouble
    "else" => KwElse
    "enum" => KwEnum
    "extern" => KwExtern
    "float" => KwFloat
    "for" => KwFor
    "goto" => KwGoto
    "if" => KwIf
    "inline" | "__inline" | "__inline__" | "_inline" | "__forceinline" =>
      KwInline
    "int" | "__int32" => KwInt
    "long" => KwLong
    "register" => KwRegister
    "restrict" | "__restrict" | "__restrict__" => KwRestrict
    "return" => KwReturn
    "short" => KwShort
    "signed" | "__signed" | "__signed__" => KwSigned
    "sizeof" => KwSizeof
    "static" => KwStatic
    "struct" => KwStruct
    "switch" => KwSwitch
    "typedef" => KwTypedef
    "union" => KwUnion
    "unsigned" => KwUnsigned
    "void" => KwVoid
    "volatile" | "__volatile" | "__volatile__" => KwVolatile
    "while" => KwWhile
    "_Bool" => KwBool
    "_Float16" => KwFloat
    "_Complex" => KwComplex
    "_Imaginary" => KwImaginary
    "_Alignof" | "__alignof" | "__alignof__" => KwAlignof
    "_Alignas" => KwAlignAs
    "_Atomic" => KwAtomic
    "_Generic" => KwGeneric
    "_Noreturn" | "__noreturn__" => KwNoreturn
    "_Static_assert" => KwStaticAssert
    "_Thread_local" | "__thread" => KwThread
    "asm" | "__asm" | "__asm__" => KwAsm
    "_Pragma" => KwPragma
    "__attribute" | "__attribute__" => KwAttribute
    "__blockattribute__" | "__blockattribute" => KwBlockAttribute
    "typeof" | "__typeof" | "__typeof__" => KwTypeof
    "__extension__" => KwExtension
    "__builtin_va_arg" => KwBuiltinVaArg
    "__builtin_va_list" => KwBuiltinVaList
    "__builtin_offsetof" => KwBuiltinOffsetof
    "__builtin_types_compatible_p" => KwBuiltinTypesCompat
    "__FUNCTION__" | "__func__" => KwFunctionName
    "__PRETTY_FUNCTION__" => KwPrettyFunctionName
    "__label__" => KwLabel
    "__int128" | "__int128_t" | "__uint128_t" => KwInt128(text.to_string())
    "__declspec" => KwDeclspec
    "__int64" => KwInt64
    "_cdecl" | "__cdecl" => KwMsAttr("__cdecl")
    "_stdcall" | "__stdcall" => KwMsAttr("__stdcall")
    "_fastcall" | "__fastcall" => KwMsAttr("__fastcall")
    "__w64" => KwMsAttr("__w64")
    "__try" => KwTry
    "__except" => KwExcept
    "__finally" => KwFinally
    "_Nullable"
    | "__nullable"
    | "_Nonnull"
    | "__nonnull"
    | "_Null_unspecified" => KwNullability(text.to_string())
    "__TAGGED"
    | "__RTTI"
    | "__FSEQ"
    | "__FSEQN"
    | "__COMPAT"
    | "__SAFE"
    | "__WILD"
    | "__SEQ"
    | "__SEQN"
    | "__SIZED"
    | "__PTROF"
    | "__SELECTEDWHEN"
    | "__SAFEUNION"
    | "SAFEUNION"
    | "__INDEX"
    | "__STRING"
    | "__ROSTRING"
    | "__NULLTERM"
    | "__NONNULL"
    | "__BND"
    | "__BNDNULL"
    | "__TRUSTED"
    | "__RTTI_TRUSTED"
    | "__COUNT"
    | "__COUNTOF"
    | "__HEAPIFY"
    | "__HASROOM"
    | "__OPTSTRING"
    | "__SENTINEL"
    | "__CONTAINER"
    | "__ROOM"
    | "__AUTORESTRICT"
    | "__AUTOSELECT"
    | "__NOCUREBLOCK" => KwCcuredAttr(text.to_string())
    _ =>
      if self.context.is_type_name(text.to_string()) {
        NamedType(text.to_string())
      } else {
        Ident(text.to_string())
      }
  }
}

///|
fn Lexer::read_number(self : Lexer) -> Token {
  let start = self.pos
  if self.peek() == '0' && (self.peek_next() == 'x' || self.peek_next() == 'X') {
    let _ = self.advance()
    let _ = self.advance()
    while !self.is_eof() && is_hex_digit(self.peek()) {
      let _ = self.advance()

    }
    while !self.is_eof() &&
          (
            self.peek() == 'u' ||
            self.peek() == 'U' ||
            self.peek() == 'l' ||
            self.peek() == 'L'
          ) {
      let _ = self.advance()

    }
    return IntConst(try! self.source[start:self.pos].to_string())
  }
  while !self.is_eof() && is_digit(self.peek()) {
    let _ = self.advance()

  }
  let mut is_float = false
  if self.peek() == '.' {
    let next = self.peek_next()
    if next == '.' {
      ()
    } else if !is_alpha_or_underscore(next) {
      is_float = true
      let _ = self.advance()
      while !self.is_eof() && is_digit(self.peek()) {
        let _ = self.advance()

      }
    }
  }
  if self.peek() == 'e' || self.peek() == 'E' {
    is_float = true
    let _ = self.advance()
    if self.peek() == '+' || self.peek() == '-' {
      let _ = self.advance()

    }
    while not(self.is_eof()) && is_digit(self.peek()) {
      let _ = self.advance()

    }
  }
  if is_float {
    if self.peek() == 'f' ||
      self.peek() == 'F' ||
      self.peek() == 'l' ||
      self.peek() == 'L' {
      let _ = self.advance()

    }
    FloatConst(try! self.source[start:self.pos].to_string())
  } else {
    while !self.is_eof() &&
          (
            self.peek() == 'u' ||
            self.peek() == 'U' ||
            self.peek() == 'l' ||
            self.peek() == 'L'
          ) {
      let _ = self.advance()

    }
    IntConst(try! self.source[start:self.pos].to_string())
  }
}

///|
fn parse_escape_char(c : Char) -> Char {
  match c {
    'n' => '\n'
    'r' => '\r'
    't' => '\t'
    '0' => '\u{00}'
    '\\' => '\\'
    '"' => '"'
    '\'' => '\''
    'a' => '\u{07}'
    'b' => '\u{08}'
    'f' => '\u{0C}'
    'v' => '\u{0B}'
    _ => c
  }
}

///|
fn Lexer::read_string(self : Lexer) -> Token {
  let _ = self.advance()
  let result = StringBuilder::new()
  while !self.is_eof() && self.peek() != '"' {
    if self.peek() == '\\' {
      let _ = self.advance()
      if !self.is_eof() {
        let escaped = self.advance()
        result.write_string(String::make(1, parse_escape_char(escaped)))
      }
    } else {
      result.write_string(String::make(1, self.advance()))
    }
  }
  if self.peek() == '"' {
    let _ = self.advance()

  }
  StringConst(result.to_string())
}

///|
fn Lexer::read_char(self : Lexer) -> Token {
  let _ = self.advance()
  let result = StringBuilder::new()
  while not(self.is_eof()) && self.peek() != '\'' {
    if self.peek() == '\\' {
      let _ = self.advance()
      if not(self.is_eof()) {
        let escaped = self.advance()
        result.write_string(String::make(1, parse_escape_char(escaped)))
      }
    } else {
      result.write_string(String::make(1, self.advance()))
    }
  }
  if self.peek() == '\'' {
    let _ = self.advance()

  }
  CharConst(result.to_string())
}

///|
pub fn Lexer::next_token(self : Lexer) -> Token {
  self.skip_whitespace()
  if self.is_eof() {
    return Eof
  }
  let c = self.peek()
  if is_ident_start(c) {
    if c == 'L' && self.peek_next() == '"' {
      let _ = self.advance()
      match self.read_string() {
        StringConst(s) => return WideStringConst(s)
        _ => ()
      }
    }
    if c == 'L' && self.peek_next() == '\'' {
      let _ = self.advance()
      match self.read_char() {
        CharConst(s) => return WideCharConst(s)
        _ => ()
      }
    }
    return self.read_identifier()
  }
  if is_digit(c) {
    return self.read_number()
  }
  if c == '"' {
    return self.read_string()
  }
  if c == '\'' {
    return self.read_char()
  }
  let _ = self.advance()
  match c {
    '+' =>
      if self.peek() == '+' {
        let _ = self.advance()
        PlusPlus
      } else if self.peek() == '=' {
        let _ = self.advance()
        PlusEq
      } else {
        Plus
      }
    '-' =>
      if self.peek() == '-' {
        let _ = self.advance()
        MinusMinus
      } else if self.peek() == '=' {
        let _ = self.advance()
        MinusEq
      } else if self.peek() == '>' {
        let _ = self.advance()
        Arrow
      } else {
        Minus
      }
    '*' =>
      if self.peek() == '=' {
        let _ = self.advance()
        StarEq
      } else {
        Star
      }
    '/' =>
      if self.peek() == '=' {
        let _ = self.advance()
        SlashEq
      } else {
        Slash
      }
    '%' =>
      if self.peek() == '=' {
        let _ = self.advance()
        PercentEq
      } else {
        Percent
      }
    '&' =>
      if self.peek() == '&' {
        let _ = self.advance()
        AmpAmp
      } else if self.peek() == '=' {
        let _ = self.advance()
        AmpEq
      } else {
        Amp
      }
    '|' =>
      if self.peek() == '|' {
        let _ = self.advance()
        PipePipe
      } else if self.peek() == '=' {
        let _ = self.advance()
        PipeEq
      } else {
        Pipe
      }
    '^' =>
      if self.peek() == '=' {
        let _ = self.advance()
        CaretEq
      } else {
        Caret
      }
    '~' => Tilde
    '!' =>
      if self.peek() == '=' {
        let _ = self.advance()
        BangEq
      } else {
        Bang
      }
    '=' =>
      if self.peek() == '=' {
        let _ = self.advance()
        EqEq
      } else {
        Eq
      }
    '<' =>
      if self.peek() == '<' {
        let _ = self.advance()
        if self.peek() == '=' {
          let _ = self.advance()
          LtLtEq
        } else {
          LtLt
        }
      } else if self.peek() == '=' {
        let _ = self.advance()
        LtEq
      } else {
        Lt
      }
    '>' =>
      if self.peek() == '>' {
        let _ = self.advance()
        if self.peek() == '=' {
          let _ = self.advance()
          GtGtEq
        } else {
          GtGt
        }
      } else if self.peek() == '=' {
        let _ = self.advance()
        GtEq
      } else {
        Gt
      }
    '?' => Question
    ':' => Colon
    '.' =>
      if self.peek() == '.' && self.peek_next() == '.' {
        let _ = self.advance()
        let _ = self.advance()
        Ellipsis
      } else {
        Dot
      }
    ',' => Comma
    ';' => Semi
    '(' => LParen
    ')' => RParen
    '[' => LBracket
    ']' => RBracket
    '{' => LBrace
    '}' => RBrace
    '#' =>
      if self.peek() == '#' {
        let _ = self.advance()
        HashHash
      } else {
        Hash
      }
    '@' => {
      let start = self.pos
      while not(self.is_eof()) && is_ident_char(self.peek()) {
        let _ = self.advance()

      }
      let text = try! self.source[start:self.pos].to_string()
      match text {
        "transform" => AtTransform
        "transformExpr" => AtTransformExpr
        "specifier" => AtSpecifier
        "expr" => AtExpr
        "name" => AtName
        _ => Ident("@" + text)
      }
    }
    _ => Ident(String::make(1, c))
  }
}

///|
pub fn Lexer::location(self : Lexer) -> CabsLoc {
  { lineno: self.line, filename: self.filename, byteno: self.pos, ident: 0 }
}

///|
pub fn tokenize(source : String, filename : String) -> Array[(Token, CabsLoc)] {
  let lexer = Lexer::new(source, filename)
  let tokens = []
  while true {
    let loc = lexer.location()
    let tok = lexer.next_token()
    tokens.push((tok, loc))
    match tok {
      Eof => break
      _ => continue
    }
  }
  tokens
}

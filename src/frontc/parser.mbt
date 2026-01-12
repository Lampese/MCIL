///|
pub struct Parser {
  lexer : Lexer
  buffer : Array[(Token, CabsLoc)]
  mut pos : Int
}

///|
pub suberror ParseError {
  ParseError(String)
}

///|
pub fn Parser::new(tokens : Array[(Token, CabsLoc)]) -> Parser {
  let dummy_lexer = Lexer::new("", "")
  { lexer: dummy_lexer, buffer: tokens, pos: 0 }
}

///|
pub fn Parser::from_lexer(lexer : Lexer) -> Parser {
  { lexer, buffer: [], pos: 0 }
}

///|
fn Parser::fill_buffer(self : Parser, count : Int) -> Unit {
  while self.buffer.length() - self.pos < count {
    let loc = self.lexer.location()
    let tok = self.lexer.next_token()
    self.buffer.push((tok, loc))
    match tok {
      Eof => break
      _ => continue
    }
  }
}

///|
fn Parser::current(self : Parser) -> Token {
  self.fill_buffer(1)
  if self.pos >= self.buffer.length() {
    Eof
  } else {
    self.buffer[self.pos].0
  }
}

///|
fn Parser::current_loc(self : Parser) -> CabsLoc {
  self.fill_buffer(1)
  if self.pos >= self.buffer.length() {
    { lineno: 0, filename: "", byteno: 0, ident: 0 }
  } else {
    self.buffer[self.pos].1
  }
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.current()
  if self.pos < self.buffer.length() {
    self.pos = self.pos + 1
  }
  tok
}

///|
fn Parser::peek_next_token(self : Parser) -> Token {
  self.fill_buffer(2)
  if self.pos + 1 >= self.buffer.length() {
    Eof
  } else {
    self.buffer[self.pos + 1].0
  }
}

///|
fn Parser::add_type(self : Parser, name : String) -> Unit {
  self.lexer.context.add_type(name)
}

///|
fn Parser::add_identifier(self : Parser, name : String) -> Unit {
  self.lexer.context.add_identifier(name)
}

///|
fn Parser::push_context(self : Parser) -> Unit {
  self.lexer.context.push_context()
}

///|
fn Parser::pop_context(self : Parser) -> Unit {
  self.lexer.context.pop_context()
}

///|
fn Parser::check(self : Parser, expected : Token) -> Bool {
  match (self.current(), expected) {
    (Eof, Eof)
    | (Ident(_), Ident(_))
    | (NamedType(_), NamedType(_))
    | (IntConst(_), IntConst(_))
    | (FloatConst(_), FloatConst(_))
    | (StringConst(_), StringConst(_))
    | (CharConst(_), CharConst(_)) => true
    (a, b) => token_eq(a, b)
  }
}

///|
fn token_eq(a : Token, b : Token) -> Bool {
  match (a, b) {
    (KwAuto, KwAuto)
    | (KwBreak, KwBreak)
    | (KwCase, KwCase)
    | (KwChar, KwChar)
    | (KwConst, KwConst)
    | (KwContinue, KwContinue)
    | (KwDefault, KwDefault)
    | (KwDo, KwDo)
    | (KwDouble, KwDouble)
    | (KwElse, KwElse)
    | (KwEnum, KwEnum)
    | (KwExtern, KwExtern)
    | (KwFloat, KwFloat)
    | (KwFor, KwFor)
    | (KwGoto, KwGoto)
    | (KwIf, KwIf)
    | (KwInline, KwInline)
    | (KwInt, KwInt)
    | (KwLong, KwLong)
    | (KwLabel, KwLabel)
    | (KwRegister, KwRegister)
    | (KwRestrict, KwRestrict)
    | (KwReturn, KwReturn)
    | (KwShort, KwShort)
    | (KwSigned, KwSigned)
    | (KwSizeof, KwSizeof)
    | (KwStatic, KwStatic)
    | (KwStruct, KwStruct)
    | (KwSwitch, KwSwitch)
    | (KwTypedef, KwTypedef)
    | (KwUnion, KwUnion)
    | (KwUnsigned, KwUnsigned)
    | (KwVoid, KwVoid)
    | (KwVolatile, KwVolatile)
    | (KwWhile, KwWhile)
    | (KwBool, KwBool)
    | (Plus, Plus)
    | (Minus, Minus)
    | (Star, Star)
    | (Slash, Slash)
    | (Percent, Percent)
    | (Amp, Amp)
    | (Pipe, Pipe)
    | (Caret, Caret)
    | (Tilde, Tilde)
    | (Bang, Bang)
    | (Eq, Eq)
    | (Lt, Lt)
    | (Gt, Gt)
    | (Question, Question)
    | (Colon, Colon)
    | (Dot, Dot)
    | (Comma, Comma)
    | (Semi, Semi)
    | (LParen, LParen)
    | (RParen, RParen)
    | (LBracket, LBracket)
    | (RBracket, RBracket)
    | (LBrace, LBrace)
    | (RBrace, RBrace)
    | (PlusPlus, PlusPlus)
    | (MinusMinus, MinusMinus)
    | (Arrow, Arrow)
    | (LtLt, LtLt)
    | (GtGt, GtGt)
    | (LtEq, LtEq)
    | (GtEq, GtEq)
    | (EqEq, EqEq)
    | (BangEq, BangEq)
    | (AmpAmp, AmpAmp)
    | (PipePipe, PipePipe)
    | (Ellipsis, Ellipsis)
    | (Eof, Eof)
    | (NamedType(_), NamedType(_))
    | (KwAsm, KwAsm)
    | (KwPragma, KwPragma)
    | (KwAttribute, KwAttribute)
    | (KwTypeof, KwTypeof)
    | (KwExtension, KwExtension)
    | (KwBuiltinVaArg, KwBuiltinVaArg)
    | (KwBuiltinVaList, KwBuiltinVaList)
    | (KwBuiltinOffsetof, KwBuiltinOffsetof)
    | (KwBuiltinTypesCompat, KwBuiltinTypesCompat)
    | (KwAlignof, KwAlignof)
    | (KwAlignAs, KwAlignAs)
    | (KwTry, KwTry)
    | (KwExcept, KwExcept)
    | (KwFinally, KwFinally)
    | (AtTransform, AtTransform)
    | (AtTransformExpr, AtTransformExpr)
    | (AtSpecifier, AtSpecifier)
    | (AtExpr, AtExpr)
    | (AtName, AtName) => true
    _ => false
  }
}

///|
fn Parser::expect(self : Parser, expected : Token) -> Token raise ParseError {
  if self.check(expected) {
    self.advance()
  } else {
    raise ParseError(
      "Expected \{token_to_string(expected)}, got \{token_to_string(self.current())} at line \{self.current_loc().lineno}",
    )
  }
}

///|
fn token_to_string(tok : Token) -> String {
  match tok {
    Ident(s) => "identifier '\{s}'"
    NamedType(s) => "type '\{s}'"
    IntConst(s) => "integer '\{s}'"
    FloatConst(s) => "float '\{s}'"
    StringConst(s) => "string \"\{s}\""
    CharConst(s) => "char '\{s}'"
    KwIf => "'if'"
    KwElse => "'else'"
    KwWhile => "'while'"
    KwFor => "'for'"
    KwReturn => "'return'"
    KwInt => "'int'"
    KwVoid => "'void'"
    KwChar => "'char'"
    KwTypeof => "'typeof'"
    KwLabel => "'__label__'"
    KwSizeof => "'sizeof'"
    Semi => "';'"
    LParen => "'('"
    RParen => "')'"
    LBrace => "'{'"
    RBrace => "'}'"
    LBracket => "'['"
    RBracket => "']'"
    Star => "'*'"
    Colon => "':'"
    Comma => "','"
    Eq => "'='"
    Dot => "'.'"
    Eof => "end of file"
    _ => tok.to_string()
  }
}

///|
fn is_bad_alpha_name(name : String) -> Bool {
  if not(name.contains("___")) {
    return false
  }
  let mut i = 0
  while i + 3 < name.length() {
    if name[i] == '_' && name[i + 1] == '_' && name[i + 2] == '_' {
      let mut j = i + 3
      let mut digits = 0
      let mut all_nine = true
      while j < name.length() {
        let c = name[j]
        if c >= '0' && c <= '9' {
          digits = digits + 1
          if c != '9' {
            all_nine = false
          }
          j = j + 1
        } else {
          break
        }
      }
      if digits >= 9 && all_nine {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn Parser::is_type_specifier_start(self : Parser) -> Bool {
  match self.current() {
    KwVoid
    | KwChar
    | KwShort
    | KwInt
    | KwLong
    | KwFloat
    | KwDouble
    | KwSigned
    | KwUnsigned
    | KwBool
    | KwStruct
    | KwUnion
    | KwEnum
    | KwTypeof
    | KwBuiltinVaList
    | KwConst
    | KwVolatile
    | KwRestrict
    | KwInline
    | KwStatic
    | KwExtern
    | KwRegister
    | KwAuto
    | KwTypedef
    | NamedType(_) => true
    _ => false
  }
}

///|
fn Parser::parse_primary_expr(self : Parser) -> CabsExpression raise ParseError {
  let loc = self.current_loc()
  match self.current() {
    Ident(name) | NamedType(name) => {
      let _ = self.advance()
      Variable(name)
    }
    IntConst(s) => {
      let _ = self.advance()
      Constant(ConstInt(s))
    }
    FloatConst(s) => {
      let _ = self.advance()
      Constant(ConstFloat(s))
    }
    StringConst(s) => {
      let _ = self.advance()
      let mut combined = s
      while true {
        match self.current() {
          StringConst(s2) => {
            let _ = self.advance()
            combined = combined + s2
          }
          KwFunctionName | KwPrettyFunctionName => {
            let _ = self.advance()
            combined = combined + "__FUNCTION__"
          }
          _ => break
        }
      }
      Constant(ConstString(combined))
    }
    CharConst(s) => {
      let _ = self.advance()
      let chars = []
      for c in s {
        chars.push(c.to_int().to_int64())
      }
      Constant(ConstChar(chars))
    }
    WideStringConst(s) => {
      let _ = self.advance()
      let chars = []
      for c in s {
        chars.push(c.to_int().to_int64())
      }
      while true {
        match self.current() {
          WideStringConst(s2) | StringConst(s2) => {
            let _ = self.advance()
            for c in s2 {
              chars.push(c.to_int().to_int64())
            }
          }
          _ => break
        }
      }
      Constant(ConstWstring(chars))
    }
    WideCharConst(s) => {
      let _ = self.advance()
      let chars = []
      for c in s {
        chars.push(c.to_int().to_int64())
      }
      Constant(ConstWchar(chars))
    }
    LParen => {
      let _ = self.advance()
      if self.check(LBrace) {
        let _ = self.advance()
        let block = self.parse_block_contents()
        let _ = self.expect(RBrace)
        let _ = self.expect(RParen)
        GnuBody(block)
      } else if self.is_type_specifier_start() {
        let (spec, decl) = self.parse_type_name()
        let _ = self.expect(RParen)
        if self.check(LBrace) {
          let _ = self.advance()
          let inits = self.parse_initializer_list()
          let _ = self.expect(RBrace)
          Cast((spec, decl), CompoundInit(inits))
        } else {
          let expr = self.parse_cast_expr()
          Cast((spec, decl), SingleInit(expr))
        }
      } else {
        let expr = self.parse_expression()
        let _ = self.expect(RParen)
        Paren(expr)
      }
    }
    KwSizeof => {
      let _ = self.advance()
      if self.check(LParen) {
        let _ = self.advance()
        if self.is_type_specifier_start() {
          let (spec, decl) = self.parse_type_name()
          let _ = self.expect(RParen)
          TypeSizeof(spec, decl)
        } else {
          let expr = self.parse_expression()
          let _ = self.expect(RParen)
          ExprSizeof(Paren(expr))
        }
      } else {
        let expr = self.parse_unary_expr()
        ExprSizeof(expr)
      }
    }
    KwAlignof => {
      let _ = self.advance()
      if self.check(LParen) {
        let _ = self.advance()
        if self.is_type_specifier_start() {
          let (spec, decl) = self.parse_type_name()
          let _ = self.expect(RParen)
          TypeAlignof(spec, decl)
        } else {
          let expr = self.parse_expression()
          let _ = self.expect(RParen)
          ExprAlignof(Paren(expr))
        }
      } else {
        let expr = self.parse_unary_expr()
        ExprAlignof(expr)
      }
    }
    KwFunctionName => {
      let _ = self.advance()
      Constant(ConstString("__FUNCTION__"))
    }
    KwPrettyFunctionName => {
      let _ = self.advance()
      Constant(ConstString("__PRETTY_FUNCTION__"))
    }
    KwExtension => {
      let _ = self.advance()
      self.parse_unary_expr()
    }
    KwBuiltinVaArg => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let ap_expr = self.parse_assignment_expr()
      let _ = self.expect(Comma)
      let (spec, decl) = self.parse_type_name()
      let _ = self.expect(RParen)
      Call(Variable("__builtin_va_arg"), [ap_expr, TypeSizeof(spec, decl)])
    }
    KwBuiltinOffsetof => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let (spec, decl) = self.parse_type_name()
      let _ = self.expect(Comma)
      let member_expr = self.parse_offsetof_member_designator()
      let _ = self.expect(RParen)
      transform_offsetof(spec, decl, member_expr)
    }
    KwBuiltinTypesCompat => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let (spec1, decl1) = self.parse_type_name()
      let _ = self.expect(Comma)
      let (spec2, decl2) = self.parse_type_name()
      let _ = self.expect(RParen)
      Call(Variable("__builtin_types_compatible_p"), [
        TypeSizeof(spec1, decl1),
        TypeSizeof(spec2, decl2),
      ])
    }
    AtExpr => {
      // @expr(name) - expression pattern variable for patch system
      let _ = self.advance()
      let _ = self.expect(LParen)
      let name = match self.current() {
        Ident(n) => {
          let _ = self.advance()
          n
        }
        _ => raise ParseError("Expected identifier in @expr")
      }
      let _ = self.expect(RParen)
      ExprPattern(name)
    }
    _ =>
      raise ParseError(
        "Unexpected token \{token_to_string(self.current())} at line \{loc.lineno}",
      )
  }
}

///|
fn Parser::parse_offsetof_member_designator(
  self : Parser,
) -> CabsExpression raise ParseError {
  let name = match self.current() {
    Ident(n) | NamedType(n) => {
      let _ = self.advance()
      n
    }
    _ => raise ParseError("Expected identifier in offsetof member designator")
  }
  let mut expr : CabsExpression = Variable(name)
  while true {
    match self.current() {
      Dot => {
        let _ = self.advance()
        match self.current() {
          Ident(field) | NamedType(field) => {
            let _ = self.advance()
            expr = MemberOf(expr, field)
          }
          _ => raise ParseError("Expected field name after '.' in offsetof")
        }
      }
      LBracket => {
        let _ = self.advance()
        let index = self.parse_expression()
        let _ = self.expect(RBracket)
        expr = Index(expr, index)
      }
      _ => break
    }
  }
  expr
}

///|
fn transform_offsetof(
  spec : Specifier,
  decl : DeclType,
  field_expr : CabsExpression,
) -> CabsExpression {
  fn add_pointer(dt : DeclType) -> DeclType {
    match dt {
      JustBase => Ptr([], JustBase)
      ParenType(a1, inner, a2) => ParenType(a1, add_pointer(inner), a2)
      Array(inner, attrs, size) => Array(add_pointer(inner), attrs, size)
      Ptr(attrs, inner) => Ptr(attrs, add_pointer(inner))
      Proto(inner, params, vararg) => Proto(add_pointer(inner), params, vararg)
    }
  }

  let null_type = (spec, add_pointer(decl))
  let null_expr = Constant(ConstInt("0"))
  let cast_expr = Cast(null_type, SingleInit(null_expr))
  fn replace_base(e : CabsExpression, base : CabsExpression) -> CabsExpression {
    match e {
      Variable(field) => MemberOfPtr(base, field)
      MemberOf(inner, field) => MemberOf(replace_base(inner, base), field)
      Index(inner, idx) => Index(replace_base(inner, base), idx)
      _ => e
    }
  }

  let member_result = replace_base(field_expr, cast_expr)
  let addr_expr = Unary(Addrof, member_result)
  let sizet_spec = Specifier([SpecType(Tunsigned), SpecType(Tlong)])
  Cast((sizet_spec, JustBase), SingleInit(addr_expr))
}

///|
fn Parser::parse_postfix_expr(self : Parser) -> CabsExpression raise ParseError {
  let mut expr = self.parse_primary_expr()
  while true {
    match self.current() {
      LBracket => {
        let _ = self.advance()
        let index = self.parse_expression()
        let _ = self.expect(RBracket)
        expr = Index(expr, index)
      }
      LParen => {
        let _ = self.advance()
        let args = self.parse_argument_list()
        let _ = self.expect(RParen)
        expr = Call(expr, args)
      }
      Dot => {
        let _ = self.advance()
        match self.current() {
          Ident(name) | NamedType(name) => {
            let _ = self.advance()
            expr = MemberOf(expr, name)
          }
          _ => raise ParseError("Expected member name after '.'")
        }
      }
      Arrow => {
        let _ = self.advance()
        match self.current() {
          Ident(name) | NamedType(name) => {
            let _ = self.advance()
            expr = MemberOfPtr(expr, name)
          }
          _ => raise ParseError("Expected member name after '->'")
        }
      }
      PlusPlus => {
        let _ = self.advance()
        expr = Unary(Posincr, expr)
      }
      MinusMinus => {
        let _ = self.advance()
        expr = Unary(Posdecr, expr)
      }
      _ => break
    }
  }
  expr
}

///|
fn Parser::parse_argument_list(
  self : Parser,
) -> Array[CabsExpression] raise ParseError {
  let args : Array[CabsExpression] = []
  if not(self.check(RParen)) {
    args.push(self.parse_assignment_expr())
    while self.check(Comma) {
      let _ = self.advance()
      args.push(self.parse_assignment_expr())
    }
  }
  args
}

///|
fn Parser::parse_unary_expr(self : Parser) -> CabsExpression raise ParseError {
  match self.current() {
    PlusPlus => {
      let _ = self.advance()
      let expr = self.parse_unary_expr()
      Unary(Preincr, expr)
    }
    MinusMinus => {
      let _ = self.advance()
      let expr = self.parse_unary_expr()
      Unary(Predecr, expr)
    }
    AmpAmp => {
      let _ = self.advance()
      match self.current() {
        Ident(name) => {
          let _ = self.advance()
          LabelAddr(name)
        }
        _ => {
          self.pos = self.pos - 1
          self.parse_postfix_expr()
        }
      }
    }
    Amp => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(Addrof, expr)
    }
    Star => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(Memof, expr)
    }
    Plus => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(CabsUnaryOp::Plus, expr)
    }
    Minus => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(CabsUnaryOp::Minus, expr)
    }
    Tilde => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(Bnot, expr)
    }
    Bang => {
      let _ = self.advance()
      let expr = self.parse_cast_expr()
      Unary(Not, expr)
    }
    KwSizeof => self.parse_primary_expr()
    _ => self.parse_postfix_expr()
  }
}

///|
fn Parser::parse_cast_expr(self : Parser) -> CabsExpression raise ParseError {
  if self.check(LParen) {
    let saved_pos = self.pos
    let _ = self.advance()
    if self.is_type_specifier_start() {
      let (spec, decl) = self.parse_type_name() catch {
        _ => {
          self.pos = saved_pos
          return self.parse_unary_expr()
        }
      }
      if not(self.check(RParen)) {
        self.pos = saved_pos
        return self.parse_unary_expr()
      }
      let _ = self.advance()
      if self.check(LBrace) {
        let _ = self.advance()
        let inits = self.parse_initializer_list()
        let _ = self.expect(RBrace)
        Cast((spec, decl), CompoundInit(inits))
      } else {
        let expr = self.parse_cast_expr()
        Cast((spec, decl), SingleInit(expr))
      }
    } else {
      self.pos = saved_pos
      self.parse_unary_expr()
    }
  } else {
    self.parse_unary_expr()
  }
}

///|
fn Parser::parse_binary_expr(
  self : Parser,
  min_prec : Int,
) -> CabsExpression raise ParseError {
  let mut left = self.parse_cast_expr()
  while true {
    let (op, prec) = match self.current() {
      Star => (Some(CabsBinaryOp::Mul), 13)
      Slash => (Some(CabsBinaryOp::Div), 13)
      Percent => (Some(CabsBinaryOp::Mod), 13)
      Plus => (Some(CabsBinaryOp::Add), 12)
      Minus => (Some(CabsBinaryOp::Sub), 12)
      LtLt => (Some(Shl), 11)
      GtGt => (Some(Shr), 11)
      Lt => (Some(CabsBinaryOp::Lt), 10)
      Gt => (Some(CabsBinaryOp::Gt), 10)
      LtEq => (Some(CabsBinaryOp::Le), 10)
      GtEq => (Some(CabsBinaryOp::Ge), 10)
      EqEq => (Some(CabsBinaryOp::Eq), 9)
      BangEq => (Some(CabsBinaryOp::Ne), 9)
      Amp => (Some(Band), 8)
      Caret => (Some(Xor), 7)
      Pipe => (Some(Bor), 6)
      AmpAmp => (Some(CabsBinaryOp::And), 5)
      PipePipe => (Some(CabsBinaryOp::Or), 4)
      _ => (None, 0)
    }
    match op {
      None => break
      Some(bin_op) =>
        if prec < min_prec {
          break
        } else {
          let _ = self.advance()
          let right = self.parse_binary_expr(prec + 1)
          left = Binary(bin_op, left, right)
        }
    }
  }
  left
}

///|
fn Parser::parse_conditional_expr(
  self : Parser,
) -> CabsExpression raise ParseError {
  let cond = self.parse_binary_expr(1)
  if self.check(Question) {
    let _ = self.advance()
    let then_expr = if self.check(Colon) {
      Nothing
    } else {
      self.parse_expression()
    }
    let _ = self.expect(Colon)
    let else_expr = self.parse_conditional_expr()
    Question(cond, then_expr, else_expr)
  } else {
    cond
  }
}

///|
fn Parser::parse_assignment_expr(
  self : Parser,
) -> CabsExpression raise ParseError {
  let left = self.parse_conditional_expr()
  let assign_op = match self.current() {
    Eq => Some(CabsBinaryOp::Assign)
    PlusEq => Some(AddAssign)
    MinusEq => Some(SubAssign)
    StarEq => Some(MulAssign)
    SlashEq => Some(DivAssign)
    PercentEq => Some(ModAssign)
    AmpEq => Some(BandAssign)
    PipeEq => Some(BorAssign)
    CaretEq => Some(XorAssign)
    LtLtEq => Some(ShlAssign)
    GtGtEq => Some(ShrAssign)
    _ => None
  }
  match assign_op {
    Some(op) => {
      let _ = self.advance()
      let right = self.parse_assignment_expr()
      Binary(op, left, right)
    }
    None => left
  }
}

///|
pub fn Parser::parse_expression(
  self : Parser,
) -> CabsExpression raise ParseError {
  let expr = self.parse_assignment_expr()
  if self.check(Comma) {
    let exprs : Array[CabsExpression] = [expr]
    while self.check(Comma) {
      let _ = self.advance()
      exprs.push(self.parse_assignment_expr())
    }
    Comma(exprs)
  } else {
    expr
  }
}

///|
fn has_type_specifier(specs : Array[SpecElem]) -> Bool {
  for spec in specs {
    match spec {
      SpecType(_) => return true
      _ => continue
    }
  }
  false
}

///|
fn Parser::parse_specifier(self : Parser) -> Specifier raise ParseError {
  let specs : Array[SpecElem] = []
  while true {
    let elem = match self.current() {
      KwVoid => {
        let _ = self.advance()
        Some(SpecType(Tvoid))
      }
      KwChar => {
        let _ = self.advance()
        Some(SpecType(Tchar))
      }
      KwShort => {
        let _ = self.advance()
        Some(SpecType(Tshort))
      }
      KwInt => {
        let _ = self.advance()
        Some(SpecType(Tint))
      }
      KwLong => {
        let _ = self.advance()
        Some(SpecType(Tlong))
      }
      KwFloat => {
        let _ = self.advance()
        Some(SpecType(Tfloat))
      }
      KwDouble => {
        let _ = self.advance()
        Some(SpecType(Tdouble))
      }
      KwSigned => {
        let _ = self.advance()
        Some(SpecType(Tsigned))
      }
      KwUnsigned => {
        let _ = self.advance()
        Some(SpecType(Tunsigned))
      }
      KwBool => {
        let _ = self.advance()
        Some(SpecType(Tbool))
      }
      KwConst => {
        let _ = self.advance()
        Some(SpecCV(CvConst))
      }
      KwVolatile => {
        let _ = self.advance()
        Some(SpecCV(CvVolatile))
      }
      KwRestrict => {
        let _ = self.advance()
        Some(SpecCV(CvRestrict))
      }
      KwStatic => {
        let _ = self.advance()
        Some(SpecStorage(CabsStorage::Static))
      }
      KwExtern => {
        let _ = self.advance()
        Some(SpecStorage(Extern))
      }
      KwRegister => {
        let _ = self.advance()
        Some(SpecStorage(Register))
      }
      KwAuto => {
        let _ = self.advance()
        Some(SpecStorage(Auto))
      }
      KwTypedef => {
        let _ = self.advance()
        Some(SpecTypedef)
      }
      KwInline => {
        let _ = self.advance()
        Some(SpecInline)
      }
      KwStruct => {
        let _ = self.advance()
        let (name, fields, attrs) = self.parse_struct_or_union()
        Some(SpecType(Tstruct(name, fields, attrs)))
      }
      KwUnion => {
        let _ = self.advance()
        let (name, fields, attrs) = self.parse_struct_or_union()
        Some(SpecType(Tunion(name, fields, attrs)))
      }
      KwEnum => {
        let _ = self.advance()
        let (name, items, attrs) = self.parse_enum()
        Some(SpecType(Tenum(name, items, attrs)))
      }
      NamedType(name) =>
        if has_type_specifier(specs) {
          let next = self.peek_next_token()
          match next {
            LParen | LBracket | Semi | Comma | Eq | RParen | Star => None
            _ => {
              let _ = self.advance()
              Some(SpecType(Tnamed(name)))
            }
          }
        } else {
          let _ = self.advance()
          Some(SpecType(Tnamed(name)))
        }
      KwBuiltinVaList => {
        let _ = self.advance()
        Some(SpecType(Tnamed("__builtin_va_list")))
      }
      KwInt128(name) => {
        let _ = self.advance()
        Some(SpecType(Tnamed(name)))
      }
      KwTypeof => {
        let _ = self.advance()
        let _ = self.expect(LParen)
        // Distinguish between typeof(type) and typeof(expression)
        // If it looks like a type specifier, parse as TtypeofT
        if self.is_type_specifier_start() {
          let (spec, decl) = self.parse_type_name()
          let _ = self.expect(RParen)
          Some(SpecType(TtypeofT(spec, decl)))
        } else {
          let expr = self.parse_expression()
          let _ = self.expect(RParen)
          Some(SpecType(TtypeofE(expr)))
        }
      }
      KwExtension => {
        let _ = self.advance()
        continue
      }
      KwAttribute => {
        let _ = self.advance()
        let attrs = self.parse_attribute_list()
        for attr in attrs {
          specs.push(SpecAttr(attr))
        }
        continue
      }
      KwDeclspec => {
        let _ = self.advance()
        let attrs = self.parse_attribute_list()
        for attr in attrs {
          specs.push(SpecAttr(attr))
        }
        continue
      }
      KwMsAttr(name) => {
        let _ = self.advance()
        specs.push(SpecAttr({ name, args: [] }))
        continue
      }
      KwCcuredAttr(name) => {
        let _ = self.advance()
        let args = self.parse_ccured_attr_args()
        specs.push(SpecAttr({ name, args }))
        continue
      }
      KwThread => {
        let _ = self.advance()
        Some(SpecStorage(CabsStorage::Static))
      }
      KwInt64 => {
        let _ = self.advance()
        Some(SpecType(Tint64))
      }
      AtSpecifier => {
        // @specifier(name) - pattern variable for patch system
        let _ = self.advance()
        let _ = self.expect(LParen)
        let name = match self.current() {
          Ident(n) => {
            let _ = self.advance()
            n
          }
          _ => raise ParseError("Expected identifier in @specifier")
        }
        let _ = self.expect(RParen)
        Some(SpecPattern(name))
      }
      _ => None
    }
    match elem {
      Some(e) => specs.push(e)
      None => break
    }
  }
  specs
}

///|
fn Parser::parse_struct_or_union(
  self : Parser,
) -> (String, Array[FieldGroup]?, Array[CabsAttribute]) raise ParseError {
  let attrs : Array[CabsAttribute] = []
  while self.check(KwAttribute) || self.check(KwDeclspec) {
    let _ = self.advance()
    let parsed_attrs = self.parse_attribute_list()
    for attr in parsed_attrs {
      attrs.push(attr)
    }
  }
  let name = match self.current() {
    Ident(n) | NamedType(n) => {
      let _ = self.advance()
      n
    }
    _ => ""
  }
  let fields = if self.check(LBrace) {
    let _ = self.advance()
    let fs = self.parse_field_list()
    let _ = self.expect(RBrace)
    Some(fs)
  } else {
    None
  }
  (name, fields, attrs)
}

///|
fn Parser::parse_field_list(
  self : Parser,
) -> Array[FieldGroup] raise ParseError {
  let fields : Array[FieldGroup] = []
  while not(self.check(RBrace)) {
    let spec = self.parse_specifier()
    let decls = self.parse_field_declarators()
    let _ = self.expect(Semi)
    fields.push({ spec, fields: decls })
  }
  fields
}

///|
fn Parser::parse_field_declarators(
  self : Parser,
) -> Array[(Name, CabsExpression?)] raise ParseError {
  let decls : Array[(Name, CabsExpression?)] = []
  let (name, bitfield) = self.parse_field_declarator()
  decls.push((name, bitfield))
  while self.check(Comma) {
    let _ = self.advance()
    let (name2, bitfield2) = self.parse_field_declarator()
    decls.push((name2, bitfield2))
  }
  decls
}

///|
fn Parser::parse_field_declarator(
  self : Parser,
) -> (Name, CabsExpression?) raise ParseError {
  let loc = self.current_loc()
  let (decl_name, decl_type, decl_attrs) = self.parse_declarator()
  let bitfield = if self.check(Colon) {
    let _ = self.advance()
    Some(self.parse_conditional_expr())
  } else {
    None
  }
  let attrs = decl_attrs
  while self.check(KwAttribute) || self.check(KwDeclspec) {
    let _ = self.advance()
    attrs.append(self.parse_attribute_list())
  }
  ({ name: decl_name, decl_type, attrs, loc }, bitfield)
}

///|
fn Parser::parse_enum(
  self : Parser,
) -> (String, Array[EnumItem]?, Array[CabsAttribute]) raise ParseError {
  let name = match self.current() {
    Ident(n) => {
      let _ = self.advance()
      n
    }
    _ => ""
  }
  let items = if self.check(LBrace) {
    let _ = self.advance()
    let enum_items = self.parse_enum_items()
    let _ = self.expect(RBrace)
    Some(enum_items)
  } else {
    None
  }
  (name, items, [])
}

///|
fn Parser::parse_enum_items(self : Parser) -> Array[EnumItem] raise ParseError {
  let items : Array[EnumItem] = []
  while not(self.check(RBrace)) {
    let loc = self.current_loc()
    match self.current() {
      Ident(name) => {
        let _ = self.advance()
        while self.check(KwAttribute) || self.check(KwDeclspec) {
          let _ = self.advance()
          let _ = self.parse_attribute_list()

        }
        let value = if self.check(Eq) {
          let _ = self.advance()
          self.parse_conditional_expr()
        } else {
          Nothing
        }
        items.push({ name, value, loc })
        if self.check(Comma) {
          let _ = self.advance()

        }
      }
      _ => break
    }
  }
  items
}

///|
fn Parser::parse_attribute_list(self : Parser) -> Array[CabsAttribute] {
  let attrs : Array[CabsAttribute] = []
  if self.check(LParen) {
    let _ = self.advance()
    let double_paren = self.check(LParen)
    if double_paren {
      let _ = self.advance()

    }
    let mut paren_depth = 1
    while paren_depth > 0 && not(self.check(Eof)) {
      match self.current() {
        LParen => {
          paren_depth = paren_depth + 1
          let _ = self.advance()

        }
        RParen => {
          paren_depth = paren_depth - 1
          let _ = self.advance()

        }
        _ => {
          let _ = self.advance()

        }
      }
    }
    if double_paren && self.check(RParen) {
      let _ = self.advance()

    }
  }
  attrs
}

///|
fn Parser::parse_ccured_attr_args(
  self : Parser,
) -> Array[CabsExpression] raise ParseError {
  let args : Array[CabsExpression] = []
  if not(self.check(LParen)) {
    return args
  }
  let _ = self.advance()
  if self.check(RParen) {
    let _ = self.advance()
    return args
  }
  args.push(self.parse_expression())
  while self.check(Comma) {
    let _ = self.advance()
    args.push(self.parse_expression())
  }
  let _ = self.expect(RParen)
  args
}

///|
fn Parser::take_trailing_attributes(
  self : Parser,
) -> Array[CabsAttribute] raise ParseError {
  let out : Array[CabsAttribute] = []
  while true {
    match self.current() {
      KwAttribute | KwDeclspec => {
        let _ = self.advance()
        let _ = self.parse_attribute_list()

      }
      KwAsm => {
        let _ = self.advance()
        if self.check(LParen) {
          let _ = self.parse_attribute_list()

        }
      }
      KwCcuredAttr(name) => {
        let _ = self.advance()
        let args = self.parse_ccured_attr_args()
        out.push({ name, args })
      }
      _ => break
    }
  }
  out
}

///|
fn Parser::parse_declarator(
  self : Parser,
) -> (String, DeclType, Array[CabsAttribute]) raise ParseError {
  let mut decl_type = JustBase
  while true {
    while true {
      match self.current() {
        KwCcuredAttr(_) => {
          let _ = self.advance()

        }
        _ => break
      }
    }
    if not(self.check(Star)) {
      break
    }
    let _ = self.advance()
    let ptr_attrs : Array[CabsAttribute] = []
    while true {
      match self.current() {
        KwConst | KwVolatile | KwRestrict | KwNullability(_) | KwMsAttr(_) => {
          let _ = self.advance()

        }
        KwCcuredAttr(name) => {
          let _ = self.advance()
          ptr_attrs.push({ name, args: [] })
        }
        KwAttribute | KwDeclspec => {
          let _ = self.advance()
          let _ = self.parse_attribute_list()

        }
        _ => break
      }
    }
    decl_type = Ptr(ptr_attrs, decl_type)
  }
  let (name, inner) = self.parse_direct_declarator()
  let trailing_attrs = self.take_trailing_attributes()
  fn combine(outer : DeclType, inner : DeclType) -> DeclType {
    match outer {
      JustBase => inner
      Ptr(attrs, base) => Ptr(attrs, combine(base, inner))
      Array(base, attrs, size) => Array(combine(base, inner), attrs, size)
      Proto(base, params, vararg) => Proto(combine(base, inner), params, vararg)
      ParenType(a1, base, a2) => ParenType(a1, combine(base, inner), a2)
    }
  }

  (name, combine(decl_type, inner), trailing_attrs)
}

///|
fn Parser::parse_direct_declarator(
  self : Parser,
) -> (String, DeclType) raise ParseError {
  let (name, base) = if self.check(LParen) {
    let _ = self.advance()
    while true {
      match self.current() {
        KwMsAttr(_) | KwAttribute | KwDeclspec => {
          let _ = self.advance()
          if self.check(LParen) {
            let _ = self.parse_attribute_list()

          }
        }
        _ => break
      }
    }
    let (n, d, _) = self.parse_declarator()
    let _ = self.expect(RParen)
    (n, d)
  } else {
    match self.current() {
      Ident(n) | NamedType(n) => {
        if is_bad_alpha_name(n) {
          raise ParseError(
            "Encountered a variable name containing ___ and many digits",
          )
        }
        let _ = self.advance()
        (n, JustBase)
      }
      KwRestrict => {
        let _ = self.advance()
        ("restrict", JustBase)
      }
      _ => ("", JustBase)
    }
  }
  let mut decl_type = base
  while true {
    if self.check(LBracket) {
      let _ = self.advance()
      let size = if self.check(RBracket) {
        Nothing
      } else {
        self.parse_conditional_expr()
      }
      let _ = self.expect(RBracket)
      decl_type = Array(decl_type, [], size)
    } else if self.check(LParen) {
      let _ = self.advance()
      let (params, vararg) = self.parse_parameter_list()
      let _ = self.expect(RParen)
      decl_type = Proto(decl_type, params, vararg)
    } else {
      break
    }
  }
  (name, decl_type)
}

///|
fn Parser::parse_parameter_list(
  self : Parser,
) -> (Array[SingleName], Bool) raise ParseError {
  let params : Array[SingleName] = []
  let mut vararg = false
  if not(self.check(RParen)) {
    if self.check(KwVoid) {
      let saved_pos = self.pos
      let _ = self.advance()
      if self.check(RParen) {
        return (params, false)
      }
      self.pos = saved_pos
    }
    let param = self.parse_parameter_declaration()
    params.push(param)
    while self.check(Comma) {
      let _ = self.advance()
      if self.check(Ellipsis) {
        let _ = self.advance()
        vararg = true
        break
      }
      params.push(self.parse_parameter_declaration())
    }
  }
  (params, vararg)
}

///|
fn Parser::parse_parameter_declaration(
  self : Parser,
) -> SingleName raise ParseError {
  let spec = self.parse_specifier()
  let loc = self.current_loc()
  let (name, decl_type, attrs) = self.parse_declarator()
  { spec, name: { name, decl_type, attrs, loc } }
}

///|
fn Parser::parse_type_name(
  self : Parser,
) -> (Specifier, DeclType) raise ParseError {
  let spec = self.parse_specifier()
  let (_, decl_type, _) = self.parse_declarator()
  (spec, decl_type)
}

///|
fn Parser::parse_asm_template(self : Parser) -> Array[String] {
  let templates : Array[String] = []
  while true {
    match self.current() {
      StringConst(s) => {
        let _ = self.advance()
        templates.push(s)
      }
      _ => break
    }
  }
  templates
}

///|
fn Parser::parse_asm_operands(
  self : Parser,
) -> Array[(String?, String, CabsExpression)] raise ParseError {
  let operands : Array[(String?, String, CabsExpression)] = []
  if self.check(Colon) || self.check(RParen) {
    return operands
  }
  operands.push(self.parse_asm_operand())
  while self.check(Comma) {
    let _ = self.advance()
    operands.push(self.parse_asm_operand())
  }
  operands
}

///|
fn Parser::parse_asm_operand(
  self : Parser,
) -> (String?, String, CabsExpression) raise ParseError {
  let name = if self.check(LBracket) {
    let _ = self.advance()
    let n = match self.current() {
      Ident(s) => {
        let _ = self.advance()
        s
      }
      _ => raise ParseError("Expected identifier in asm operand name")
    }
    let _ = self.expect(RBracket)
    Some(n)
  } else {
    None
  }
  let constraint = match self.current() {
    StringConst(s) => {
      let _ = self.advance()
      s
    }
    _ => raise ParseError("Expected string constraint in asm operand")
  }
  let _ = self.expect(LParen)
  let expr = self.parse_expression()
  let _ = self.expect(RParen)
  (name, constraint, expr)
}

///|
fn Parser::parse_asm_clobbers(self : Parser) -> Array[String] {
  let clobbers : Array[String] = []
  if self.check(RParen) {
    return clobbers
  }
  match self.current() {
    StringConst(s) => {
      let _ = self.advance()
      clobbers.push(s)
    }
    _ => return clobbers
  }
  while self.check(Comma) {
    let _ = self.advance()
    match self.current() {
      StringConst(s) => {
        let _ = self.advance()
        clobbers.push(s)
      }
      _ => break
    }
  }
  clobbers
}

///|
pub fn Parser::parse_statement(self : Parser) -> CabsStatement raise ParseError {
  let loc = self.current_loc()
  match self.current() {
    LBrace => {
      let _ = self.advance()
      let block = self.parse_block_contents()
      let _ = self.expect(RBrace)
      Block(block, loc)
    }
    KwIf => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let cond = self.parse_expression()
      let _ = self.expect(RParen)
      let then_stmt = self.parse_statement()
      let else_stmt = if self.check(KwElse) {
        let _ = self.advance()
        self.parse_statement()
      } else {
        Nop(loc)
      }
      If(cond, then_stmt, else_stmt, loc)
    }
    KwWhile => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let cond = self.parse_expression()
      let _ = self.expect(RParen)
      let body = self.parse_statement()
      While(cond, body, loc)
    }
    KwDo => {
      let _ = self.advance()
      let body = self.parse_statement()
      let _ = self.expect(KwWhile)
      let _ = self.expect(LParen)
      let cond = self.parse_expression()
      let _ = self.expect(RParen)
      let _ = self.expect(Semi)
      DoWhile(cond, body, loc)
    }
    KwFor => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let init = if self.check(Semi) {
        let _ = self.advance()
        FcExp(Nothing)
      } else if self.is_type_specifier_start() {
        let decl = self.parse_declaration()
        FcDecl(decl)
      } else {
        let expr = self.parse_expression()
        let _ = self.expect(Semi)
        FcExp(expr)
      }
      let cond = if self.check(Semi) {
        Nothing
      } else {
        self.parse_expression()
      }
      let _ = self.expect(Semi)
      let update = if self.check(RParen) {
        Nothing
      } else {
        self.parse_expression()
      }
      let _ = self.expect(RParen)
      let body = self.parse_statement()
      For(init, cond, update, body, loc)
    }
    KwSwitch => {
      let _ = self.advance()
      let _ = self.expect(LParen)
      let expr = self.parse_expression()
      let _ = self.expect(RParen)
      let body = self.parse_statement()
      Switch(expr, body, loc)
    }
    KwCase => {
      let _ = self.advance()
      let expr = self.parse_conditional_expr()
      if self.check(Ellipsis) {
        let _ = self.advance()
        let expr2 = self.parse_conditional_expr()
        let _ = self.expect(Colon)
        let stmt = if self.check(RBrace) {
          Nop(loc)
        } else {
          self.parse_statement()
        }
        CaseRange(expr, expr2, stmt, loc)
      } else {
        let _ = self.expect(Colon)
        let stmt = if self.check(RBrace) {
          Nop(loc)
        } else {
          self.parse_statement()
        }
        Case(expr, stmt, loc)
      }
    }
    KwDefault => {
      let _ = self.advance()
      let _ = self.expect(Colon)
      let stmt = if self.check(RBrace) {
        Nop(loc)
      } else {
        self.parse_statement()
      }
      Default(stmt, loc)
    }
    KwBreak => {
      let _ = self.advance()
      let _ = self.expect(Semi)
      Break(loc)
    }
    KwContinue => {
      let _ = self.advance()
      let _ = self.expect(Semi)
      Continue(loc)
    }
    KwReturn => {
      let _ = self.advance()
      let expr = if self.check(Semi) {
        Nothing
      } else {
        self.parse_expression()
      }
      let _ = self.expect(Semi)
      Return(expr, loc)
    }
    KwGoto => {
      let _ = self.advance()
      match self.current() {
        Ident(name) => {
          let _ = self.advance()
          let _ = self.expect(Semi)
          Goto(name, loc)
        }
        Star => {
          let _ = self.advance()
          let expr = self.parse_expression()
          let _ = self.expect(Semi)
          CompGoto(expr, loc)
        }
        _ => raise ParseError("Expected label name after 'goto'")
      }
    }
    Semi => {
      let _ = self.advance()
      Nop(loc)
    }
    Ident(name) =>
      if self.peek_next_token() is Colon {
        let _ = self.advance()
        let _ = self.advance()
        while self.check(KwAttribute) || self.check(KwDeclspec) {
          let _ = self.advance()
          let _ = self.parse_attribute_list()

        }
        let stmt = self.parse_statement()
        Label(name, stmt, loc)
      } else {
        let expr = self.parse_expression()
        let _ = self.expect(Semi)
        Computation(expr, loc)
      }
    NamedType(name) =>
      if self.peek_next_token() is Colon {
        let _ = self.advance()
        let _ = self.advance()
        while self.check(KwAttribute) || self.check(KwDeclspec) {
          let _ = self.advance()
          let _ = self.parse_attribute_list()

        }
        let stmt = self.parse_statement()
        Label(name, stmt, loc)
      } else {
        let decl = self.parse_declaration()
        StatDefinition(decl)
      }
    KwAsm => {
      let _ = self.advance()
      let attrs : Array[CabsAttribute] = []
      while self.check(KwVolatile) || self.check(KwConst) {
        let _ = self.advance()

      }
      let _ = self.expect(LParen)
      let template = self.parse_asm_template()
      let details = if self.check(Colon) {
        let _ = self.advance()
        let outputs = self.parse_asm_operands()
        let inputs = if self.check(Colon) {
          let _ = self.advance()
          self.parse_asm_operands()
        } else {
          []
        }
        let clobbers = if self.check(Colon) {
          let _ = self.advance()
          self.parse_asm_clobbers()
        } else {
          []
        }
        Some({ aoutputs: outputs, ainputs: inputs, aclobbers: clobbers })
      } else {
        None
      }
      let _ = self.expect(RParen)
      let _ = self.expect(Semi)
      Asm(attrs, template, details, loc)
    }
    // MSVC __try/__except and __try/__finally
    KwTry => {
      let _ = self.advance()
      let _ = self.expect(LBrace)
      let try_block = self.parse_block_contents()
      let _ = self.expect(RBrace)
      if self.check(KwExcept) {
        // __try { } __except(expr) { }
        let _ = self.advance()
        let _ = self.expect(LParen)
        let filter_expr = self.parse_expression()
        let _ = self.expect(RParen)
        let _ = self.expect(LBrace)
        let except_block = self.parse_block_contents()
        let _ = self.expect(RBrace)
        TryExcept(try_block, filter_expr, except_block, loc)
      } else if self.check(KwFinally) {
        // __try { } __finally { }
        let _ = self.advance()
        let _ = self.expect(LBrace)
        let finally_block = self.parse_block_contents()
        let _ = self.expect(RBrace)
        TryFinally(try_block, finally_block, loc)
      } else {
        raise ParseError("Expected '__except' or '__finally' after '__try'")
      }
    }
    _ =>
      if self.is_type_specifier_start() {
        let decl = self.parse_declaration()
        StatDefinition(decl)
      } else {
        let expr = self.parse_expression()
        let _ = self.expect(Semi)
        Computation(expr, loc)
      }
  }
}

///|
fn Parser::parse_block_contents(self : Parser) -> CabsBlock raise ParseError {
  let blabels : Array[String] = []
  while self.check(KwLabel) {
    let _ = self.advance()
    match self.current() {
      Ident(name) => {
        let _ = self.advance()
        blabels.push(name)
      }
      _ => ()
    }
    while self.check(Comma) {
      let _ = self.advance()
      match self.current() {
        Ident(name) => {
          let _ = self.advance()
          blabels.push(name)
        }
        _ => ()
      }
    }
    let _ = self.expect(Semi)

  }
  let battrs : Array[CabsAttribute] = []
  while true {
    match self.current() {
      KwCcuredAttr(name) => {
        let _ = self.advance()
        if self.check(LParen) {
          let _ = self.parse_attribute_list()

        }
        battrs.push({ name, args: [] })
      }
      KwBlockAttribute => {
        let _ = self.advance()
        if self.check(LParen) {
          let _ = self.advance()
          match self.current() {
            Ident(attr_name) => {
              let _ = self.advance()
              battrs.push({
                name: "__blockattribute__",
                args: [Variable(attr_name)],
              })
            }
            _ => ()
          }
          let _ = self.expect(RParen)

        }
      }
      _ => break
    }
  }
  let stmts : Array[CabsStatement] = []
  while not(self.check(RBrace)) && not(self.check(Eof)) {
    stmts.push(self.parse_statement())
  }
  { blabels, battrs, bstmts: stmts }
}

///|
fn is_typedef_spec(spec : Specifier) -> Bool {
  let Specifier(elems) = spec
  let mut i = 0
  while i < elems.length() {
    match elems[i] {
      SpecTypedef => return true
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
fn Parser::parse_declaration(self : Parser) -> Definition raise ParseError {
  let loc = self.current_loc()
  let spec = self.parse_specifier()
  if self.check(Semi) {
    let _ = self.advance()
    return OnlyTypeDef(spec, loc)
  }
  let init_names = self.parse_init_declarator_list()
  let _ = self.expect(Semi)
  let is_typedef = is_typedef_spec(spec)
  if is_typedef {
    for init_name in init_names {
      self.add_type(init_name.name.name)
    }
    let names : Array[Name] = init_names.map(fn(in_) { in_.name })
    TypeDef({ spec, names }, loc)
  } else {
    for init_name in init_names {
      self.add_identifier(init_name.name.name)
    }
    DecDef({ spec, init_names }, loc)
  }
}

///|
fn Parser::parse_init_declarator_list(
  self : Parser,
) -> Array[InitName] raise ParseError {
  let decls : Array[InitName] = []
  let init_name = self.parse_init_declarator()
  decls.push(init_name)
  while self.check(Comma) {
    let _ = self.advance()
    decls.push(self.parse_init_declarator())
  }
  decls
}

///|
fn Parser::parse_init_declarator(self : Parser) -> InitName raise ParseError {
  let loc = self.current_loc()
  let (name, decl_type, attrs) = self.parse_declarator()
  let init = if self.check(Eq) {
    let _ = self.advance()
    self.parse_initializer()
  } else {
    NoInit
  }
  { name: { name, decl_type, attrs, loc }, init }
}

///|
fn Parser::parse_initializer(self : Parser) -> InitExpression raise ParseError {
  if self.check(LBrace) {
    let _ = self.advance()
    let inits = self.parse_initializer_list()
    let _ = self.expect(RBrace)
    CompoundInit(inits)
  } else {
    SingleInit(self.parse_assignment_expr())
  }
}

///|
fn Parser::parse_initializer_list(
  self : Parser,
) -> Array[(InitWhat, InitExpression)] raise ParseError {
  let inits : Array[(InitWhat, InitExpression)] = []
  while not(self.check(RBrace)) {
    let what = self.parse_designator()
    let init = self.parse_initializer()
    inits.push((what, init))
    if self.check(Comma) {
      let _ = self.advance()

    } else {
      break
    }
  }
  inits
}

///|
fn Parser::parse_designator(self : Parser) -> InitWhat raise ParseError {
  let mut what = NextInit
  match self.current() {
    Ident(name) | NamedType(name) =>
      if self.peek_next_token() is Colon {
        let _ = self.advance()
        let _ = self.advance()
        return InfieldInit(name, NextInit)
      }
    _ => ()
  }
  while true {
    if self.check(Dot) {
      let _ = self.advance()
      match self.current() {
        Ident(name) | NamedType(name) => {
          let _ = self.advance()
          what = InfieldInit(name, what)
        }
        _ => raise ParseError("Expected field name after '.'")
      }
    } else if self.check(LBracket) {
      let _ = self.advance()
      let index = self.parse_conditional_expr()
      if self.check(Ellipsis) {
        let _ = self.advance()
        let end_index = self.parse_conditional_expr()
        let _ = self.expect(RBracket)
        what = AtindexRangeInit(index, end_index)
      } else {
        let _ = self.expect(RBracket)
        what = AtindexInit(index, what)
      }
    } else {
      break
    }
  }
  let is_next_init = match what {
    NextInit => true
    _ => false
  }
  if not(is_next_init) {
    if self.check(Eq) {
      let _ = self.advance()

    }
  }
  what
}

///|
fn extract_param_names(decl : DeclType) -> Array[String] {
  let names : Array[String] = []
  fn find_proto(d : DeclType) {
    match d {
      Proto(inner, params, _) => {
        for param in params {
          if param.name.name != "" {
            names.push(param.name.name)
          }
        }
        find_proto(inner)
      }
      Ptr(_, inner) => find_proto(inner)
      Array(inner, _, _) => find_proto(inner)
      ParenType(_, inner, _) => find_proto(inner)
      JustBase => ()
    }
  }

  find_proto(decl)
  names
}

///|
fn Parser::parse_old_pardef_list(
  self : Parser,
) -> Array[(Specifier, Array[Name])] raise ParseError {
  let pardefs : Array[(Specifier, Array[Name])] = []
  while not(self.check(LBrace)) && not(self.check(Eof)) {
    let pspec = self.parse_specifier()
    let names : Array[Name] = []
    if not(self.check(Semi)) {
      let decl_loc = self.current_loc()
      let (pname, pdecl, pattrs) = self.parse_declarator()
      names.push({ name: pname, decl_type: pdecl, attrs: pattrs, loc: decl_loc })
      while self.check(Comma) {
        let _ = self.advance()
        let decl_loc2 = self.current_loc()
        let (pname2, pdecl2, pattrs2) = self.parse_declarator()
        names.push({
          name: pname2,
          decl_type: pdecl2,
          attrs: pattrs2,
          loc: decl_loc2,
        })
      }
    }
    let _ = self.expect(Semi)
    pardefs.push((pspec, names))
  }
  pardefs
}

///|
fn convert_old_pardefs(
  decl_type : DeclType,
  pardefs : Array[(Specifier, Array[Name])],
) -> DeclType {
  fn get_old_param_names(d : DeclType) -> (Array[String], DeclType) {
    match d {
      Proto(inner, params, vararg) => ([], Proto(inner, params, vararg))
      _ => ([], d)
    }
  }

  fn find_param_type(
    name : String,
    pardefs : Array[(Specifier, Array[Name])],
  ) -> (Specifier, DeclType)? {
    for pardef in pardefs {
      let (spec, names) = pardef
      for n in names {
        if n.name == name {
          return Some((spec, n.decl_type))
        }
      }
    }
    None
  }

  fn rebuild_proto(d : DeclType) -> DeclType {
    match d {
      Proto(inner, params, vararg) => {
        let new_params : Array[SingleName] = []
        for param in params {
          match find_param_type(param.name.name, pardefs) {
            Some((spec, decl)) =>
              new_params.push({
                spec,
                name: {
                  name: param.name.name,
                  decl_type: decl,
                  attrs: [],
                  loc: param.name.loc,
                },
              })
            None =>
              new_params.push({
                spec: Specifier([SpecType(Tint)]),
                name: param.name,
              })
          }
        }
        Proto(rebuild_proto(inner), new_params, vararg)
      }
      Ptr(attrs, inner) => Ptr(attrs, rebuild_proto(inner))
      Array(inner, attrs, size) => Array(rebuild_proto(inner), attrs, size)
      ParenType(a1, inner, a2) => ParenType(a1, rebuild_proto(inner), a2)
      JustBase => JustBase
    }
  }

  let (_, _) = get_old_param_names(decl_type)
  rebuild_proto(decl_type)
}

///|
pub fn Parser::parse_definition(self : Parser) -> Definition raise ParseError {
  let loc = self.current_loc()
  // Handle global asm: __asm__("...");
  if self.check(KwAsm) {
    let _ = self.advance()
    let _ = self.expect(LParen)
    let asm_str = match self.current() {
      StringConst(s) => {
        let _ = self.advance()
        s
      }
      _ => raise ParseError("Expected string in global asm")
    }
    let _ = self.expect(RParen)
    let _ = self.expect(Semi)
    return GlobAsm(asm_str, loc)
  }
  // Handle _Pragma("...")
  if self.check(KwPragma) {
    let _ = self.advance()
    let _ = self.expect(LParen)
    let expr = self.parse_expression()
    let _ = self.expect(RParen)
    return Pragma(expr, loc)
  }
  // Handle @transform { definition } to { definitions }
  if self.check(AtTransform) {
    let _ = self.advance()
    let _ = self.expect(LBrace)
    let src_def = self.parse_definition()
    let _ = self.expect(RBrace)
    // Expect "to" identifier
    match self.current() {
      Ident(s) =>
        if s != "to" {
          raise ParseError("Expected 'to' in @transform, got '\{s}'")
        }
      _ => raise ParseError("Expected 'to' in @transform")
    }
    let _ = self.advance()
    let _ = self.expect(LBrace)
    let dest_defs : Array[Definition] = []
    while not(self.check(RBrace)) && not(self.check(Eof)) {
      dest_defs.push(self.parse_definition())
    }
    let _ = self.expect(RBrace)
    return Transformer(src_def, dest_defs, loc)
  }
  // Handle @transformExpr { expression } to { expression }
  if self.check(AtTransformExpr) {
    let _ = self.advance()
    let _ = self.expect(LBrace)
    let src_expr = self.parse_expression()
    let _ = self.expect(RBrace)
    // Expect "to" identifier
    match self.current() {
      Ident(s) =>
        if s != "to" {
          raise ParseError("Expected 'to' in @transformExpr, got '\{s}'")
        }
      _ => raise ParseError("Expected 'to' in @transformExpr")
    }
    let _ = self.advance()
    let _ = self.expect(LBrace)
    let dest_expr = self.parse_expression()
    let _ = self.expect(RBrace)
    return ExprTransformer(src_expr, dest_expr, loc)
  }
  if self.check(KwExtern) {
    let saved_pos = self.pos
    let _ = self.advance()
    match self.current() {
      StringConst(linkage_str) => {
        let _ = self.advance()
        if self.check(LBrace) {
          let _ = self.advance()
          let defs : Array[Definition] = []
          while not(self.check(RBrace)) && not(self.check(Eof)) {
            defs.push(self.parse_definition())
          }
          let _ = self.expect(RBrace)
          return Linkage(linkage_str, loc, defs)
        } else {
          let def = self.parse_definition()
          return Linkage(linkage_str, loc, [def])
        }
      }
      _ => self.pos = saved_pos
    }
  }
  let spec = self.parse_specifier()
  if self.check(Semi) {
    let _ = self.advance()
    return OnlyTypeDef(spec, loc)
  }
  let decl_loc = self.current_loc()
  let (name, decl_type, attrs) = self.parse_declarator()
  match self.current() {
    LBrace => {
      self.add_identifier(name)
      self.push_context()
      let param_names = extract_param_names(decl_type)
      for pname in param_names {
        self.add_identifier(pname)
      }
      let _ = self.advance()
      let body = self.parse_block_contents()
      let _ = self.expect(RBrace)
      self.pop_context()
      let end_loc = self.current_loc()
      FunDef(
        { spec, name: { name, decl_type, attrs, loc: decl_loc } },
        body,
        loc,
        end_loc,
      )
    }
    _ =>
      if self.is_type_specifier_start() {
        self.add_identifier(name)
        self.push_context()
        let param_names = extract_param_names(decl_type)
        for pname in param_names {
          self.add_identifier(pname)
        }
        let pardefs = self.parse_old_pardef_list()
        let new_decl_type = convert_old_pardefs(decl_type, pardefs)
        let _ = self.expect(LBrace)
        let body = self.parse_block_contents()
        let _ = self.expect(RBrace)
        self.pop_context()
        let end_loc = self.current_loc()
        FunDef(
          {
            spec,
            name: { name, decl_type: new_decl_type, attrs, loc: decl_loc },
          },
          body,
          loc,
          end_loc,
        )
      } else {
        let init = if self.check(Eq) {
          let _ = self.advance()
          self.parse_initializer()
        } else {
          NoInit
        }
        let init_names : Array[InitName] = [
          { name: { name, decl_type, attrs, loc: decl_loc }, init },
        ]
        while self.check(Comma) {
          let _ = self.advance()
          init_names.push(self.parse_init_declarator())
        }
        let _ = self.expect(Semi)
        let is_typedef = is_typedef_spec(spec)
        if is_typedef {
          for init_name in init_names {
            self.add_type(init_name.name.name)
          }
          let names : Array[Name] = init_names.map(fn(in_) { in_.name })
          TypeDef({ spec, names }, loc)
        } else {
          for init_name in init_names {
            self.add_identifier(init_name.name.name)
          }
          DecDef({ spec, init_names }, loc)
        }
      }
  }
}

///|
fn Parser::skip_test_markers(self : Parser) -> Unit {
  while true {
    match self.current() {
      StringConst(_) =>
        if self.peek_next_token() is Colon {
          while not(self.check(Eof)) && not(self.is_type_specifier_start()) {
            let _ = self.advance()

          }
        } else {
          break
        }
      Ident(_) =>
        if self.peek_next_token() is Colon {
          while not(self.check(Eof)) && not(self.is_type_specifier_start()) {
            let _ = self.advance()

          }
        } else {
          break
        }
      _ => break
    }
  }
}

///|
pub fn Parser::parse_file(self : Parser) -> CabsFile raise ParseError {
  let definitions : Array[Definition] = []
  while not(self.check(Eof)) {
    self.skip_test_markers()
    if self.check(Eof) {
      break
    }
    definitions.push(self.parse_definition())
  }
  { filename: "", definitions }
}

///|
pub fn parse_c_source(
  source : String,
  filename : String,
) -> CabsFile raise ParseError {
  let lexer = Lexer::new(source, filename)
  let parser = Parser::from_lexer(lexer)
  parser.parse_file()
}

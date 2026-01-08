///|
pub fn compare_exp(e1 : Exp, e2 : Exp) -> Bool {
  match (e1, e2) {
    (Lval(lv1), Lval(lv2)) => compare_lval(lv1, lv2)
    (StartOf(lv1), StartOf(lv2)) => compare_lval(lv1, lv2)
    (AddrOf(lv1), AddrOf(lv2)) => compare_lval(lv1, lv2)
    (Const(c1), Const(c2)) => compare_constant(c1, c2)
    (UnOp(op1, inner1, _), UnOp(op2, inner2, _)) =>
      compare_unop(op1, op2) && compare_exp(inner1, inner2)
    (BinOp(op1, l1, r1, _), BinOp(op2, l2, r2, _)) =>
      compare_binop(op1, op2) && compare_exp(l1, l2) && compare_exp(r1, r2)
    (CastE(t1, inner1), CastE(t2, inner2)) =>
      compare_type(t1, t2) && compare_exp(inner1, inner2)
    (SizeOf(t1), SizeOf(t2)) => compare_type(t1, t2)
    (SizeOfE(inner1), SizeOfE(inner2)) => compare_exp(inner1, inner2)
    (SizeOfStr(s1), SizeOfStr(s2)) => s1 == s2
    (AlignOf(t1), AlignOf(t2)) => compare_type(t1, t2)
    (AlignOfE(inner1), AlignOfE(inner2)) => compare_exp(inner1, inner2)
    (Question(c1, t1, e1, _), Question(c2, t2, e2, _)) =>
      compare_exp(c1, c2) && compare_exp(t1, t2) && compare_exp(e1, e2)
    (AddrOfLabel(sr1), AddrOfLabel(sr2)) => sr1.sid == sr2.sid
    _ => false
  }
}

///|
pub fn compare_lval(lv1 : LVal, lv2 : LVal) -> Bool {
  compare_lhost(lv1.host, lv2.host) && compare_offset(lv1.offset, lv2.offset)
}

///|
fn compare_lhost(h1 : LHost, h2 : LHost) -> Bool {
  match (h1, h2) {
    (Var(vi1), Var(vi2)) => vi1.vid == vi2.vid
    (Mem(e1), Mem(e2)) => compare_exp(e1, e2)
    _ => false
  }
}

///|
fn compare_offset(off1 : Offset, off2 : Offset) -> Bool {
  match (off1, off2) {
    (NoOffset, NoOffset) => true
    (Field(fi1, rest1), Field(fi2, rest2)) =>
      fi1.fname == fi2.fname &&
      fi1.fcomp.ckey == fi2.fcomp.ckey &&
      compare_offset(rest1, rest2)
    (Index(e1, rest1), Index(e2, rest2)) =>
      compare_exp(e1, e2) && compare_offset(rest1, rest2)
    _ => false
  }
}

///|
fn compare_constant(c1 : Constant, c2 : Constant) -> Bool {
  match (c1, c2) {
    (CInt64(v1, ik1, _), CInt64(v2, ik2, _)) => v1 == v2 && ik1 == ik2
    (CStr(s1), CStr(s2)) => s1 == s2
    (CWStr(w1), CWStr(w2)) =>
      if w1.length() != w2.length() {
        false
      } else {
        let mut i = 0
        let mut same = true
        while i < w1.length() && same {
          if w1[i] != w2[i] {
            same = false
          }
          i = i + 1
        }
        same
      }
    (CChr(c1), CChr(c2)) => c1 == c2
    (CReal(v1, fk1, _), CReal(v2, fk2, _)) => v1 == v2 && fk1 == fk2
    (CEnum(_, n1, ei1), CEnum(_, n2, ei2)) => n1 == n2 && ei1.ename == ei2.ename
    _ => false
  }
}

///|
fn compare_unop(op1 : UnOp, op2 : UnOp) -> Bool {
  match (op1, op2) {
    (Neg, Neg) => true
    (BNot, BNot) => true
    (LNot, LNot) => true
    _ => false
  }
}

///|
fn compare_binop(op1 : BinOp, op2 : BinOp) -> Bool {
  match (op1, op2) {
    (PlusA, PlusA) => true
    (PlusPI, PlusPI) => true
    (IndexPI, IndexPI) => true
    (MinusA, MinusA) => true
    (MinusPI, MinusPI) => true
    (MinusPP, MinusPP) => true
    (Mult, Mult) => true
    (Div, Div) => true
    (Mod, Mod) => true
    (Shiftlt, Shiftlt) => true
    (Shiftrt, Shiftrt) => true
    (Lt, Lt) => true
    (Gt, Gt) => true
    (Le, Le) => true
    (Ge, Ge) => true
    (Eq, Eq) => true
    (Ne, Ne) => true
    (BAnd, BAnd) => true
    (BXor, BXor) => true
    (BOr, BOr) => true
    (LAnd, LAnd) => true
    (LOr, LOr) => true
    _ => false
  }
}

///|
fn compare_type(t1 : Typ, t2 : Typ) -> Bool {
  match (t1, t2) {
    (TVoid(_), TVoid(_)) => true
    (TInt(ik1, _), TInt(ik2, _)) => ik1 == ik2
    (TFloat(fk1, _), TFloat(fk2, _)) => fk1 == fk2
    (TPtr(inner1, _), TPtr(inner2, _)) => compare_type(inner1, inner2)
    (TArray(elem1, len1, _), TArray(elem2, len2, _)) =>
      compare_type(elem1, elem2) && compare_array_len(len1, len2)
    (TFun(ret1, args1, va1, _), TFun(ret2, args2, va2, _)) =>
      compare_type(ret1, ret2) && va1 == va2 && compare_args(args1, args2)
    (TNamed(ti1, _), TNamed(ti2, _)) => ti1.tname == ti2.tname
    (TComp(ci1, _), TComp(ci2, _)) => ci1.ckey == ci2.ckey
    (TEnum(ei1, _), TEnum(ei2, _)) => ei1.ename == ei2.ename
    (TBuiltinVaList(_), TBuiltinVaList(_)) => true
    _ => false
  }
}

///|
fn compare_array_len(len1 : Exp?, len2 : Exp?) -> Bool {
  match (len1, len2) {
    (None, None) => true
    (Some(e1), Some(e2)) => compare_exp(e1, e2)
    _ => false
  }
}

///|
fn compare_args(
  args1 : Array[(String, Typ, Array[Attribute])]?,
  args2 : Array[(String, Typ, Array[Attribute])]?,
) -> Bool {
  match (args1, args2) {
    (None, None) => true
    (Some(a1), Some(a2)) =>
      if a1.length() != a2.length() {
        false
      } else {
        let mut i = 0
        let mut same = true
        while i < a1.length() && same {
          let (_, t1, _) = a1[i]
          let (_, t2, _) = a2[i]
          if !compare_type(t1, t2) {
            same = false
          }
          i = i + 1
        }
        same
      }
    _ => false
  }
}

///|
pub fn strip_nop_casts(e : Exp) -> Exp {
  match e {
    CastE(t, inner) => {
      let inner_type = type_of(inner)
      if can_strip_cast(inner_type, t) {
        strip_nop_casts(inner)
      } else {
        e
      }
    }
    _ => e
  }
}

///|
fn can_strip_cast(from : Typ, to : Typ) -> Bool {
  match (unroll_type(from), unroll_type(to)) {
    (TPtr(bt1, _), TPtr(bt2, _)) => has_const_attr(bt1) == has_const_attr(bt2)
    (TInt(ik1, _), TInt(ik2, _)) => ik1 == ik2
    _ => false
  }
}

///|
fn has_const_attr(t : Typ) -> Bool {
  let attrs = get_type_attrs(t)
  attrs.iter().any(x => x.name == "const")
}

///|
fn get_type_attrs(t : Typ) -> Array[Attribute] {
  match t {
    TVoid(a) => a
    TInt(_, a) => a
    TFloat(_, a) => a
    TPtr(_, a) => a
    TArray(_, _, a) => a
    TFun(_, _, _, a) => a
    TNamed(_, a) => a
    TComp(_, a) => a
    TEnum(_, a) => a
    TBuiltinVaList(a) => a
  }
}

///|
pub fn compare_exp_strip_casts(e1 : Exp, e2 : Exp) -> Bool {
  compare_exp(strip_nop_casts(e1), strip_nop_casts(e2))
}

///|
pub fn is_constant_exp(e : Exp) -> Bool {
  match e {
    Const(_) => true
    UnOp(_, inner, _) => is_constant_exp(inner)
    BinOp(_, l, r, _) => is_constant_exp(l) && is_constant_exp(r)
    CastE(_, inner) => is_constant_exp(inner)
    SizeOf(_) | SizeOfStr(_) | AlignOf(_) => true
    SizeOfE(inner) | AlignOfE(inner) => is_constant_exp(inner)
    Question(c, t, e, _) =>
      is_constant_exp(c) && is_constant_exp(t) && is_constant_exp(e)
    _ => false
  }
}

///|
pub fn is_integer_constant(e : Exp) -> Bool {
  match e {
    Const(CInt64(_, _, _)) | Const(CChr(_)) | Const(CEnum(_, _, _)) => true
    CastE(_, inner) => is_integer_constant(inner)
    _ => false
  }
}

///|
pub fn get_integer_value(e : Exp) -> Int64? {
  match e {
    Const(CInt64(v, _, _)) => Some(v)
    Const(CChr(c)) => Some(c.to_int().to_int64())
    Const(CEnum(inner, _, _)) => get_integer_value(inner)
    CastE(_, inner) => get_integer_value(inner)
    _ => None
  }
}

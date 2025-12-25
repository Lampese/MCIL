///|
let start_id : Ref[Int] = Ref::new(0)

///|
fn next_stmt_id() -> Int {
  let id = start_id.val + 1
  start_id.val = id
  id
}

///|
pub fn reset_stmt_id() -> Unit {
  start_id.val = 0
}

///|
pub fn get_current_stmt_id() -> Int {
  start_id.val
}

///|
fn find_case_labeled_stmts(block : Block) -> Array[Stmt] {
  let result : Array[Stmt] = []
  fn is_case_label(label : Label) -> Bool {
    match label {
      Case(_, _) => true
      CaseRange(_, _, _) => true
      Default(_) => true
      Label(_, _, _) => false
    }
  }

  letrec visit_stmt = fn(s : Stmt) -> Unit {
    let has_case = s.labels.iter().any(is_case_label)
    if has_case {
      result.push(s)
    }
    match s.skind {
      Block(b) => visit_block(b)
      If(_, b1, b2, _) => {
        visit_block(b1)
        visit_block(b2)
      }
      Loop(b, _, _, _) => visit_block(b)
      Switch(_, _, _, _) => ()
      _ => ()
    }
  }
  and visit_block = fn(b : Block) -> Unit { b.bstmts.each(visit_stmt) }

  visit_block(block)
  result
}

///|
fn find_addr_of_label_stmts(block : Block) -> Array[Stmt] {
  let result : Array[Stmt] = []
  letrec visit_exp = fn(e : Exp) -> Unit {
    match e {
      AddrOfLabel(s) => result.push(s)
      UnOp(_, e1, _) => visit_exp(e1)
      BinOp(_, e1, e2, _) => {
        visit_exp(e1)
        visit_exp(e2)
      }
      Question(c, e1, e2, _) => {
        visit_exp(c)
        visit_exp(e1)
        visit_exp(e2)
      }
      CastE(_, e1) => visit_exp(e1)
      Lval(lv) => visit_lval(lv)
      AddrOf(lv) => visit_lval(lv)
      StartOf(lv) => visit_lval(lv)
      SizeOfE(e1) => visit_exp(e1)
      AlignOfE(e1) => visit_exp(e1)
      _ => ()
    }
  }
  and visit_offset = fn(off : Offset) -> Unit {
    match off {
      NoOffset => ()
      Field(_, o) => visit_offset(o)
      Index(e, o) => {
        visit_exp(e)
        visit_offset(o)
      }
    }
  }
  and visit_lval = fn(lv : LVal) -> Unit {
    match lv.host {
      Mem(e) => visit_exp(e)
      Var(_) => ()
    }
    visit_offset(lv.offset)
  }

  fn visit_instr(i : Instr) -> Unit {
    match i {
      Set(lv, e, _) => {
        visit_lval(lv)
        visit_exp(e)
      }
      Call(lv_opt, f, args, _) => {
        match lv_opt {
          Some(lv) => visit_lval(lv)
          None => ()
        }
        visit_exp(f)
        args.each(visit_exp)
      }
      Asm(_, _, outputs, inputs, _, _) => {
        outputs.each(fn(o) {
          let (_, _, lv) = o
          visit_lval(lv)
        })
        inputs.each(fn(inp) {
          let (_, _, e) = inp
          visit_exp(e)
        })
      }
    }
  }

  letrec visit_stmt = fn(s : Stmt) -> Unit {
    match s.skind {
      Instr(il) => il.each(visit_instr)
      Return(e_opt, _) =>
        match e_opt {
          Some(e) => visit_exp(e)
          None => ()
        }
      If(e, b1, b2, _) => {
        visit_exp(e)
        visit_block(b1)
        visit_block(b2)
      }
      Switch(e, b, _, _) => {
        visit_exp(e)
        visit_block(b)
      }
      Loop(b, _, _, _) => visit_block(b)
      Block(b) => visit_block(b)
      ComputedGoto(e, _) => visit_exp(e)
      Goto(_, _) | Break(_) | Continue(_) => ()
      TryFinally(b1, b2, _) => {
        visit_block(b1)
        visit_block(b2)
      }
      TryExcept(b1, (il, e), b2, _) => {
        visit_block(b1)
        il.each(visit_instr)
        visit_exp(e)
        visit_block(b2)
      }
    }
  }
  and visit_block = fn(b : Block) -> Unit { b.bstmts.each(visit_stmt) }

  visit_block(block)
  result
}

///|
pub fn cfg_fun(fd : FunDec) -> Int {
  let initial_id = start_id.val
  let node_list : Array[Stmt] = []
  let rlabels = find_addr_of_label_stmts(fd.sbody)
  cfg_block(fd.sbody, None, None, None, node_list, rlabels)
  start_id.val - initial_id
}

///|
fn cfg_stmts(
  stmts : Array[Stmt],
  next : Stmt?,
  break_stmt : Stmt?,
  cont : Stmt?,
  node_list : Array[Stmt],
  rlabels : Array[Stmt],
) -> Unit {
  let len = stmts.length()
  for i = 0; i < len; i = i + 1 {
    let s = stmts[i]
    let next_s = if i + 1 < len { Some(stmts[i + 1]) } else { next }
    cfg_stmt(s, next_s, break_stmt, cont, node_list, rlabels)
  }
}

///|
fn cfg_block(
  block : Block,
  next : Stmt?,
  break_stmt : Stmt?,
  cont : Stmt?,
  node_list : Array[Stmt],
  rlabels : Array[Stmt],
) -> Unit {
  cfg_stmts(block.bstmts, next, break_stmt, cont, node_list, rlabels)
}

///|
fn stmt_in_list(s : Stmt, list : Array[Stmt]) -> Bool {
  list.iter().any(fn(s2) { physical_equal(s, s2) })
}

///|
fn add_succ(s : Stmt, n : Stmt) -> Unit {
  if not(stmt_in_list(n, s.succs)) {
    s.succs.push(n)
  }
  if not(stmt_in_list(s, n.preds)) {
    n.preds.push(s)
  }
}

///|
fn add_option_succ(s : Stmt, n_opt : Stmt?) -> Unit {
  match n_opt {
    None => ()
    Some(n) => add_succ(s, n)
  }
}

///|
fn add_block_succ(s : Stmt, block : Block, next : Stmt?) -> Unit {
  if block.bstmts.is_empty() {
    add_option_succ(s, next)
  } else {
    add_succ(s, block.bstmts[0])
  }
}

///|
fn instr_falls_through(i : Instr) -> Bool {
  match i {
    Call(_, Lval(lv), _, _) =>
      match lv.host {
        Var(vi) => not(vi.vattr.iter().any(fn(a) { a.name == "noreturn" }))
        Mem(_) => true
      }
    Call(_, _, _, _) => true
    Set(_, _, _) => true
    Asm(_, _, _, _, _, _) => true
  }
}

///|
fn cfg_stmt(
  s : Stmt,
  next : Stmt?,
  break_stmt : Stmt?,
  cont : Stmt?,
  node_list : Array[Stmt],
  rlabels : Array[Stmt],
) -> Unit {
  let _ = next_stmt_id()
  node_list.push(s)
  guard s.succs.is_empty() else {
    abort("CFG must be cleared before being computed!")
  }
  match s.skind {
    Instr(il) =>
      if il.iter().all(instr_falls_through) {
        add_option_succ(s, next)
      }
    Return(_, _) => ()
    Goto(target, _) => add_succ(s, target)
    ComputedGoto(_, _) =>
      rlabels.each(fn(label_stmt) { add_succ(s, label_stmt) })
    Break(_) => add_option_succ(s, break_stmt)
    Continue(_) => add_option_succ(s, cont)
    If(_, blk1, blk2, _) => {
      add_block_succ(s, blk2, next)
      add_block_succ(s, blk1, next)
      cfg_block(blk1, next, break_stmt, cont, node_list, rlabels)
      cfg_block(blk2, next, break_stmt, cont, node_list, rlabels)
    }
    Block(b) => {
      add_block_succ(s, b, next)
      cfg_block(b, next, break_stmt, cont, node_list, rlabels)
    }
    Switch(_, blk, _, _) => {
      let case_stmts = find_case_labeled_stmts(blk)
      case_stmts.rev_each(fn(cs) { add_succ(s, cs) })
      let has_default = case_stmts
        .iter()
        .any(fn(cs) {
          cs.labels
          .iter()
          .any(fn(l) {
            match l {
              Default(_) => true
              _ => false
            }
          })
        })
      if not(has_default) {
        add_option_succ(s, next)
      }
      cfg_block(blk, next, next, cont, node_list, rlabels)
    }
    Loop(blk, _, _, _) => {
      add_block_succ(s, blk, Some(s))
      cfg_block(blk, Some(s), next, Some(s), node_list, rlabels)
    }
    TryFinally(_, _, _) | TryExcept(_, _, _, _) =>
      abort("try/except/finally not implemented")
  }
}

///|
pub fn forall_stmts(fd : FunDec, todo : (Stmt) -> Unit) -> Unit {
  letrec fas_block = fn(b : Block) -> Unit { b.bstmts.each(fas_stmt) }
  and fas_stmt = fn(s : Stmt) -> Unit {
    todo(s)
    match s.skind {
      Block(b) => fas_block(b)
      If(_, tb, fb, _) => {
        fas_block(tb)
        fas_block(fb)
      }
      Switch(_, b, _, _) => fas_block(b)
      Loop(b, _, _, _) => fas_block(b)
      Return(_, _)
      | Break(_)
      | Continue(_)
      | Goto(_, _)
      | ComputedGoto(_, _)
      | Instr(_) => ()
      TryFinally(_, _, _) | TryExcept(_, _, _, _) =>
        abort("try/except/finally not implemented")
    }
  }

  fas_block(fd.sbody)
}

///|
pub fn clear_cfg_info(fd : FunDec) -> Unit {
  forall_stmts(fd, fn(s) {
    s.succs.clear()
    s.preds.clear()
  })
}

///|
pub fn clear_file_cfg(f : File) -> Unit {
  start_id.val = 0
  f.globals.each(fn(g) {
    match g {
      GFun(fd, _) => clear_cfg_info(fd)
      _ => ()
    }
  })
}

///|
pub fn compute_file_cfg(f : File) -> Unit {
  f.globals.each(fn(g) {
    match g {
      GFun(fd, _) => {
        let _ = cfg_fun(fd)

      }
      _ => ()
    }
  })
}

///|
pub fn all_stmts(f : File) -> Array[Stmt] {
  let result : Array[Stmt] = []
  f.globals.each(fn(g) {
    match g {
      GFun(fd, _) => result.append(fd.sallstmts)
      _ => ()
    }
  })
  result
}

///|
fn cfg_node_name(s : Stmt) -> String {
  s.sid.to_string()
}

///|
fn cfg_node_label(s : Stmt) -> String {
  let kind_str = match s.skind {
    If(_, _, _, _) => "if"
    Loop(_, _, _, _) => "loop"
    Break(_) => "break"
    Continue(_) => "continue"
    Goto(_, _) | ComputedGoto(_, _) => "goto"
    Instr(_) => "instr"
    Switch(_, _, _, _) => "switch"
    Block(_) => "block"
    Return(_, _) => "return"
    TryExcept(_, _, _, _) => "try-except"
    TryFinally(_, _, _) => "try-finally"
  }
  "\{s.sid}: \{kind_str}"
}

///|
pub fn print_cfg_dot(fd : FunDec) -> String {
  let lines : Array[String] = []
  lines.push("digraph CFG_\{fd.svar.vname} {")
  forall_stmts(fd, fn(s) {
    let name = cfg_node_name(s)
    let label = cfg_node_label(s)
    lines.push("  \{name} [label=\"\{label}\"]")
    s.succs.each(fn(succ) { lines.push("  \{name} -> \{cfg_node_name(succ)}") })
  })
  lines.push("}")
  lines.join("\n")
}

///|
pub(all) enum Action[T] {
  Default
  Done(T)
  Post((T) -> T)
}

///|
pub(all) enum StmtAction[T] {
  SDefault
  SDone
  SUse(T)
}

///|
pub(all) enum GuardAction[T] {
  GDefault
  GUse(T)
  GUnreachable
}

///|
pub(all) struct ForwardsConfig[T] {
  name : String
  get_data : (Int) -> T?
  set_data : (Int, T) -> Unit
  has_data : (Int) -> Bool
  copy : (T) -> T
  compute_first_predecessor : (Stmt, T) -> T
  combine_predecessors : (Stmt, T, T) -> T?
  do_instr : (Instr, T) -> Action[T]
  do_stmt : (Stmt, T) -> StmtAction[T]
  do_guard : (Exp, T) -> GuardAction[T]
  filter_stmt : (Stmt) -> Bool
}

///|
pub fn[T] forwards_dataflow(
  config : ForwardsConfig[T],
  sources : Array[Stmt],
) -> Unit {
  let worklist : Array[Stmt] = []
  sources.each(fn(s) { worklist.push(s) })
  sources.each(fn(s) {
    guard (config.has_data)(s.sid) else {
      abort("FF(\{config.name}): initial stmt \{s.sid} does not have data")
    }
  })
  fn in_worklist(s : Stmt) -> Bool {
    worklist.iter().any(fn(s2) { s.sid == s2.sid })
  }

  fn reached_statement(s : Stmt, d : T) -> Unit {
    let new_data : T? = match (config.get_data)(s.sid) {
      Some(old) => (config.combine_predecessors)(s, old, d)
      None => {
        let d2 = (config.compute_first_predecessor)(s, d)
        Some(d2)
      }
    }
    match new_data {
      None => ()
      Some(d2) => {
        (config.set_data)(s.sid, d2)
        if (config.filter_stmt)(s) && not(in_worklist(s)) {
          worklist.push(s)
        }
      }
    }
  }

  fn if_succs(s : Stmt) -> (Stmt?, Stmt?) {
    match s.skind {
      If(_, b1, b2, _) => {
        let then_succ = if b1.bstmts.is_empty() {
          None
        } else {
          Some(b1.bstmts[0])
        }
        let else_succ = if b2.bstmts.is_empty() {
          None
        } else {
          Some(b2.bstmts[0])
        }
        fn get_fallthrough() -> Stmt? {
          for succ in s.succs {
            let is_then = match then_succ {
              Some(ts) => physical_equal(succ, ts)
              None => false
            }
            let is_else = match else_succ {
              Some(es) => physical_equal(succ, es)
              None => false
            }
            if not(is_then) && not(is_else) {
              break Some(succ)
            }
          } else {
            None
          }
        }

        let then_result = match then_succ {
          Some(_) => then_succ
          None => get_fallthrough()
        }
        let else_result = match else_succ {
          Some(_) => else_succ
          None => get_fallthrough()
        }
        (then_result, else_result)
      }
      _ => abort("if_succs on a non-If statement")
    }
  }

  fn process_stmt(s : Stmt) -> Unit {
    let init = match (config.get_data)(s.sid) {
      Some(d) => (config.copy)(d)
      None => abort("FF(\{config.name}): processing stmt without data")
    }
    match (config.do_stmt)(s, init) {
      SDone => ()
      SDefault | SUse(_) as act => {
        let curr = match act {
          SDefault => init
          SUse(d) => d
          SDone => abort("unreachable")
        }
        fn handle_instruction(state : T, i : Instr) -> T {
          match (config.do_instr)(i, state) {
            Done(s2) => s2
            Default => state
            Post(f) => f(state)
          }
        }

        let after = match s.skind {
          Instr(il) => il.fold(init=curr, handle_instruction)
          _ => curr
        }
        let succs_to_reach : Array[Stmt] = match s.skind {
          If(e, _, _, _) => {
            let then_guard = (config.do_guard)(e, after)
            let not_e = UnOp(LNot, e, TInt(IInt, []))
            let else_guard = (config.do_guard)(not_e, after)
            match (then_guard, else_guard) {
              (GDefault, GDefault) => s.succs
              _ => {
                let (then_succ, else_succ) = if_succs(s)
                fn do_branch(
                  succ_opt : Stmt?,
                  guard_action : GuardAction[T],
                ) -> Unit {
                  match succ_opt {
                    None => ()
                    Some(succ) =>
                      match guard_action {
                        GDefault => reached_statement(succ, after)
                        GUse(d) => reached_statement(succ, d)
                        GUnreachable => ()
                      }
                  }
                }

                do_branch(then_succ, then_guard)
                do_branch(else_succ, else_guard)
                []
              }
            }
          }
          _ => s.succs
        }
        succs_to_reach.each(fn(succ) { reached_statement(succ, after) })
      }
    }
  }

  while not(worklist.is_empty()) {
    let s = worklist.remove(0)
    process_stmt(s)
  }
}

///|
pub(all) struct BackwardsConfig[T] {
  name : String
  get_data : (Int) -> T?
  set_data : (Int, T) -> Unit
  func_exit_data : T
  combine_stmt_start_data : (Stmt, T, T) -> T?
  combine_successors : (T, T) -> T
  do_stmt : (Stmt) -> Action[T]
  do_instr : (Instr, T) -> Action[T]
  filter_stmt : (Stmt, Stmt) -> Bool
}

///|
pub fn[T] backwards_dataflow(
  config : BackwardsConfig[T],
  sinks : Array[Stmt],
) -> Unit {
  let worklist : Array[Stmt] = []
  sinks.each(fn(s) { worklist.push(s) })
  fn get_stmt_start_data(s : Stmt) -> T {
    match (config.get_data)(s.sid) {
      Some(d) => d
      None =>
        abort("BF(\{config.name}): stmtStartData not initialized for \{s.sid}")
    }
  }

  fn process_stmt(s : Stmt) -> Bool {
    let d : T = match (config.do_stmt)(s) {
      Done(d) => d
      Default | Post(_) as act => {
        let res = if s.succs.is_empty() {
          config.func_exit_data
        } else {
          let first = get_stmt_start_data(s.succs[0])
          s.succs
          .iter()
          .drop(1)
          .fold(init=first, fn(acc, succ) {
            (config.combine_successors)(acc, get_stmt_start_data(succ))
          })
        }
        let res2 = match s.skind {
          Instr(il) => {
            fn handle_instruction(state : T, i : Instr) -> T {
              match (config.do_instr)(i, state) {
                Done(s2) => s2
                Default => state
                Post(f) => f(state)
              }
            }

            il.rev_fold(init=res, handle_instruction)
          }
          _ => res
        }
        match act {
          Post(f) => f(res2)
          _ => res2
        }
      }
    }
    let s0 = get_stmt_start_data(s)
    match (config.combine_stmt_start_data)(s, s0, d) {
      None => false
      Some(d2) => {
        (config.set_data)(s.sid, d2)
        true
      }
    }
  }

  fn in_worklist(s : Stmt) -> Bool {
    worklist.iter().any(fn(s2) { s.sid == s2.sid })
  }

  while not(worklist.is_empty()) {
    let s = worklist.remove(0)
    let changes = process_stmt(s)
    if changes {
      s.preds.each(fn(p) {
        if not(in_worklist(p)) && (config.filter_stmt)(p, s) {
          worklist.push(p)
        }
      })
    }
  }
}

///|
pub fn find_stmts(fd : FunDec) -> (Array[Stmt], Array[Stmt]) {
  let all_stmts : Array[Stmt] = []
  let sink_stmts : Array[Stmt] = []
  letrec visit_block = fn(b : Block) -> Unit { b.bstmts.each(visit_stmt) }
  and visit_stmt = fn(s : Stmt) -> Unit {
    all_stmts.push(s)
    if s.succs.is_empty() {
      sink_stmts.push(s)
    }
    match s.skind {
      Block(b) => visit_block(b)
      If(_, tb, fb, _) => {
        visit_block(tb)
        visit_block(fb)
      }
      Switch(_, b, _, _) => visit_block(b)
      Loop(b, _, _, _) => visit_block(b)
      _ => ()
    }
  }

  visit_block(fd.sbody)
  (all_stmts, sink_stmts)
}

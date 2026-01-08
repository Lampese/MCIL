///|
pub struct DomInfo {
  dominators : Map[Int, @hashset.HashSet[Int]]
  idom : Map[Int, Int?]
}

///|
pub fn DomInfo::new() -> DomInfo {
  { dominators: Map::new(), idom: Map::new() }
}

///|
pub fn get_dominators(info : DomInfo, s : Stmt) -> @hashset.HashSet[Int] {
  match info.dominators.get(s.sid) {
    Some(doms) => doms
    None => @hashset.new()
  }
}

///|
pub fn get_idom(info : DomInfo, s : Stmt) -> Int? {
  match info.idom.get(s.sid) {
    Some(idom_opt) => idom_opt
    None => None
  }
}

///|
pub fn dominates(info : DomInfo, s1 : Stmt, s2 : Stmt) -> Bool {
  if s1.sid == s2.sid {
    return true
  }
  let doms = get_dominators(info, s2)
  doms.contains(s1.sid)
}

///|
pub fn compute_dominators(f : FunDec) -> DomInfo {
  let info = DomInfo::new()
  let all_stmts : Array[Stmt] = []
  collect_stmts(f.sbody, all_stmts)
  if all_stmts.is_empty() {
    return info
  }
  let all_ids : @hashset.HashSet[Int] = @hashset.new()
  for s in all_stmts {
    all_ids.add(s.sid)
  }
  let entry = all_stmts[0]
  let entry_doms : @hashset.HashSet[Int] = @hashset.new()
  entry_doms.add(entry.sid)
  info.dominators.set(entry.sid, entry_doms)
  for i = 1; i < all_stmts.length(); i = i + 1 {
    let s = all_stmts[i]
    let doms : @hashset.HashSet[Int] = @hashset.new()
    for id in all_ids {
      doms.add(id)
    }
    info.dominators.set(s.sid, doms)
  }
  let mut changed = true
  while changed {
    changed = false
    for i in 1..<all_stmts.length() {
      let s = all_stmts[i]
      let preds = s.preds
      if preds.is_empty() {
        continue
      }
      let new_doms : @hashset.HashSet[Int] = @hashset.new()
      let first_pred = preds[0]
      match info.dominators.get(first_pred.sid) {
        Some(pred_doms) =>
          for id in pred_doms {
            new_doms.add(id)
          }
        None => ()
      }
      for j in 1..<preds.length() {
        let pred = preds[j]
        match info.dominators.get(pred.sid) {
          Some(pred_doms) => {
            let to_remove = []
            for id in new_doms {
              if !pred_doms.contains(id) {
                to_remove.push(id)
              }
            }
            for id in to_remove {
              new_doms.remove(id)
            }
          }
          None => ()
        }
      }
      new_doms.add(s.sid)
      let old_doms = info.dominators.get(s.sid).unwrap_or(@hashset.new())
      if new_doms.length() != old_doms.length() {
        changed = true
        info.dominators.set(s.sid, new_doms)
      } else {
        for id in new_doms {
          if !old_doms.contains(id) {
            changed = true
            break
          }
        }
        if changed {
          info.dominators.set(s.sid, new_doms)
        }
      }
    }
  }
  compute_idom(info, all_stmts)
  info
}

///|
fn collect_stmts(b : Block, result : Array[Stmt]) -> Unit {
  for s in b.bstmts {
    result.push(s)
    match s.skind {
      If(_, then_block, else_block, _) => {
        collect_stmts(then_block, result)
        collect_stmts(else_block, result)
      }
      Switch(_, body, _, _) => collect_stmts(body, result)
      Loop(body, _, _, _) => collect_stmts(body, result)
      Block(inner) => collect_stmts(inner, result)
      TryFinally(try_block, finally_block, _) => {
        collect_stmts(try_block, result)
        collect_stmts(finally_block, result)
      }
      TryExcept(try_block, _, except_block, _) => {
        collect_stmts(try_block, result)
        collect_stmts(except_block, result)
      }
      _ => ()
    }
  }
}

///|
fn compute_idom(info : DomInfo, stmts : Array[Stmt]) -> Unit {
  let sid_to_stmt : Map[Int, Stmt] = Map::new()
  for s in stmts {
    sid_to_stmt.set(s.sid, s)
  }
  for s in stmts {
    let doms = get_dominators(info, s)
    let mut idom_candidate : Int? = None
    for dom_id in doms {
      if dom_id == s.sid {
        continue
      }
      let is_idom = match sid_to_stmt.get(dom_id) {
        Some(dom_stmt) => {
          let dom_doms = get_dominators(info, dom_stmt)
          let mut all_others_dominate = true
          for other_id in doms {
            if other_id != s.sid && other_id != dom_id {
              if not(dom_doms.contains(other_id)) {
                all_others_dominate = false
                break
              }
            }
          }
          all_others_dominate
        }
        None => false
      }
      if is_idom {
        idom_candidate = Some(dom_id)
        break
      }
    }
    info.idom.set(s.sid, idom_candidate)
  }
}

///|
pub fn build_dom_tree(info : DomInfo, f : FunDec) -> Map[Int, Array[Int]] {
  let tree = {}
  let all_stmts = []
  collect_stmts(f.sbody, all_stmts)
  for s in all_stmts {
    tree.set(s.sid, [])
  }
  for s in all_stmts {
    match get_idom(info, s) {
      Some(idom_id) =>
        match tree.get(idom_id) {
          Some(children) => children.push(s.sid)
          None => tree.set(idom_id, [s.sid])
        }
      None => ()
    }
  }
  tree
}

///|
pub fn compute_dom_frontier(
  info : DomInfo,
  f : FunDec,
) -> Map[Int, @hashset.HashSet[Int]] {
  let frontier = {}
  let all_stmts = []
  collect_stmts(f.sbody, all_stmts)
  for s in all_stmts {
    frontier.set(s.sid, @hashset.new())
  }
  for s in all_stmts {
    let preds = s.preds
    if preds.length() < 2 {
      continue
    }
    for pred in preds {
      let mut runner = pred.sid
      let idom_s = match get_idom(info, s) {
        Some(id) => id
        None => -1
      }
      while runner != idom_s && runner >= 0 {
        match frontier.get(runner) {
          Some(df) => df.add(s.sid)
          None => {
            let df : @hashset.HashSet[Int] = @hashset.new()
            df.add(s.sid)
            frontier.set(runner, df)
          }
        }
        match info.idom.get(runner) {
          Some(Some(idom_id)) => runner = idom_id
          _ => runner = -1
        }
      }
    }
  }
  frontier
}

///|
pub fn print_dom_info(info : DomInfo, f : FunDec) -> String {
  let result = StringBuilder::new()
  result.write_string("Dominator Information for \{f.svar.vname}:\n")
  let all_stmts = []
  collect_stmts(f.sbody, all_stmts)
  for s in all_stmts {
    let doms = get_dominators(info, s)
    let dom_ids = []
    for id in doms {
      dom_ids.push(id.to_string())
    }
    let sep = ", "
    result.write_string("  stmt \{s.sid}: dominators = {\{dom_ids.join(sep)}}")
    match get_idom(info, s) {
      Some(idom_id) => result.write_string(", idom = \{idom_id}")
      None => result.write_string(", idom = none")
    }
    result.write_string("\n")
  }
  result.to_string()
}

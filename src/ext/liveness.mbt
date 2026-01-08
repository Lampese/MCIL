///|
pub struct LivenessInfo {
  stmt_live_in : Map[Int, VarSet]
  stmt_live_out : Map[Int, VarSet]
}

///|
pub fn LivenessInfo::new() -> LivenessInfo {
  { stmt_live_in: {}, stmt_live_out: {} }
}

///|
pub fn get_live_in(info : LivenessInfo, s : @cil.Stmt) -> VarSet {
  match info.stmt_live_in.get(s.sid) {
    Some(vs) => vs
    None => VarSet::new()
  }
}

///|
pub fn get_live_out(info : LivenessInfo, s : @cil.Stmt) -> VarSet {
  match info.stmt_live_out.get(s.sid) {
    Some(vs) => vs
    None => VarSet::new()
  }
}

///|
pub fn is_live_at_entry(
  info : LivenessInfo,
  s : @cil.Stmt,
  vi : @cil.VarInfo,
) -> Bool {
  get_live_in(info, s).contains(vi)
}

///|
pub fn is_live_at_exit(
  info : LivenessInfo,
  s : @cil.Stmt,
  vi : @cil.VarInfo,
) -> Bool {
  get_live_out(info, s).contains(vi)
}

///|
fn collect_all_stmts(b : @cil.Block, result : Array[@cil.Stmt]) -> Unit {
  for s in b.bstmts {
    result.push(s)
    match s.skind {
      If(_, then_block, else_block, _) => {
        collect_all_stmts(then_block, result)
        collect_all_stmts(else_block, result)
      }
      Switch(_, body, _, _) => collect_all_stmts(body, result)
      Loop(body, _, _, _) => collect_all_stmts(body, result)
      Block(inner) => collect_all_stmts(inner, result)
      TryFinally(try_block, finally_block, _) => {
        collect_all_stmts(try_block, result)
        collect_all_stmts(finally_block, result)
      }
      TryExcept(try_block, _, except_block, _) => {
        collect_all_stmts(try_block, result)
        collect_all_stmts(except_block, result)
      }
      _ => ()
    }
  }
}

///|
fn transfer_instrs(instrs : Array[@cil.Instr], live_out : VarSet) -> VarSet {
  let mut live = live_out.copy()
  let mut i = instrs.length() - 1
  while i >= 0 {
    let instr = instrs[i]
    let ud = compute_instr_usedef(instr)
    live = ud.uses.union(live.diff(ud.defs))
    i = i - 1
  }
  live
}

///|
fn transfer_stmt(s : @cil.Stmt, live_out : VarSet) -> VarSet {
  match s.skind {
    Instr(instrs) => transfer_instrs(instrs, live_out)
    _ => {
      let ud = compute_stmtkind_usedef(s.skind)
      ud.uses.union(live_out.diff(ud.defs))
    }
  }
}

///|
pub fn compute_liveness(f : @cil.FunDec) -> LivenessInfo {
  let info = LivenessInfo::new()
  let all_stmts = []
  collect_all_stmts(f.sbody, all_stmts)
  if all_stmts.is_empty() {
    return info
  }
  for s in all_stmts {
    info.stmt_live_out.set(s.sid, VarSet::new())
  }
  let mut changed = true
  while changed {
    changed = false
    let mut i = all_stmts.length() - 1
    while i >= 0 {
      let s = all_stmts[i]
      let new_live_out = VarSet::new()
      for succ in s.succs {
        let succ_live_in = match info.stmt_live_in.get(succ.sid) {
          Some(vs) => vs
          None => VarSet::new()
        }
        for id in succ_live_in.0 {
          new_live_out.0.add(id)
        }
      }
      let new_live_in = transfer_stmt(s, new_live_out)
      let old_live_in = info.stmt_live_in.get(s.sid).unwrap_or(VarSet::new())
      if not(new_live_in.equal(old_live_in)) {
        changed = true
        info.stmt_live_in.set(s.sid, new_live_in)
        info.stmt_live_out.set(s.sid, new_live_out)
      }
      i = i - 1
    }
  }
  info
}

///|
pub fn get_instr_liveness(
  instrs : Array[@cil.Instr],
  live_out : VarSet,
) -> Array[VarSet] {
  let result = []
  let mut live = live_out.copy()
  let mut i = instrs.length() - 1
  while i >= 0 {
    result.push(live.copy())
    let instr = instrs[i]
    let ud = compute_instr_usedef(instr)
    live = ud.uses.union(live.diff(ud.defs))
    i = i - 1
  }
  let reversed = []
  let mut j = result.length() - 1
  while j >= 0 {
    reversed.push(result[j])
    j = j - 1
  }
  reversed
}

///|
pub fn find_dead_assignments(
  f : @cil.FunDec,
) -> Array[(@cil.Instr, @cil.VarInfo)] {
  let info = compute_liveness(f)
  let dead = []
  let vid_map = {}
  for local_ in f.slocals {
    vid_map.set(local_.vid, local_)
  }
  for formal in f.sformals {
    vid_map.set(formal.vid, formal)
  }
  let all_stmts : Array[@cil.Stmt] = []
  collect_all_stmts(f.sbody, all_stmts)
  for s in all_stmts {
    match s.skind {
      Instr(instrs) => {
        let live_out = get_live_out(info, s)
        let instr_live = get_instr_liveness(instrs, live_out)
        for i, instr in instrs {
          match instr {
            Set(lv, _, _) =>
              match lv.host {
                Var(vi) =>
                  match lv.offset {
                    NoOffset =>
                      if i < instr_live.length() &&
                        not(instr_live[i].contains(vi)) {
                        dead.push((instr, vi))
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  dead
}

///|
pub fn print_liveness_info(
  info : LivenessInfo,
  f : @cil.FunDec,
  vid_map : Map[Int, @cil.VarInfo],
) -> String {
  let result = StringBuilder::new()
  result.write_string("Liveness Analysis for \{f.svar.vname}:\n")
  let all_stmts = []
  collect_all_stmts(f.sbody, all_stmts)
  for s in all_stmts {
    let live_in = get_live_in(info, s)
    let live_out = get_live_out(info, s)
    let in_names = []
    live_in.iter(id => match vid_map.get(id) {
      Some(vi) => in_names.push(vi.vname)
      None => in_names.push("?\{id}")
    })
    let out_names = []
    live_out.iter(id => match vid_map.get(id) {
      Some(vi) => out_names.push(vi.vname)
      None => out_names.push("?\{id}")
    })
    let sep = ", "
    result.write_string(
      "  stmt \{s.sid}: in={\{in_names.join(sep)}}, out={\{out_names.join(sep)}}\n",
    )
  }
  result.to_string()
}

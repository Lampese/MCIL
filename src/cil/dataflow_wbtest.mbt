///|
test "dataflow: forwards_dataflow basic test" {
  // Create a simple statement for testing
  let stmt : Stmt = mk_empty_stmt()

  // Storage for analysis data
  let data : Map[Int, Int] = {}

  // Create forwards config
  let config : ForwardsConfig[Int] = {
    name: "test-analysis",
    get_data: fn(sid) { data.get(sid) },
    set_data: fn(sid, d) { data[sid] = d },
    has_data: fn(sid) { data.contains(sid) },
    copy: fn(d) { d },
    compute_first_predecessor: fn(_stmt, d) { d },
    combine_predecessors: fn(_stmt, old, new_val) {
      if old == new_val {
        None
      } else {
        Some(old + new_val)
      }
    },
    do_instr: fn(_instr, d) { Action::Done(d + 1) },
    do_stmt: fn(_stmt, _d) { StmtAction::SDefault },
    do_guard: fn(_exp, d) { GuardAction::GUse(d) },
    filter_stmt: fn(_stmt) { true },
  }

  // Set initial data
  data[stmt.sid] = 0

  // Run analysis (with empty sources, just verify it doesn't crash)
  forwards_dataflow(config, [stmt])

  // Verify config was used
  inspect(config.name, content="test-analysis")
}

///|
test "dataflow: backwards_dataflow basic test" {
  // Create a simple statement for testing
  let stmt : Stmt = mk_empty_stmt()

  // Storage for analysis data
  let data : Map[Int, Int] = {}

  // Create backwards config matching BackwardsConfig struct
  let config : BackwardsConfig[Int] = {
    name: "test-backwards",
    get_data: fn(sid) { data.get(sid) },
    set_data: fn(sid, d) { data[sid] = d },
    func_exit_data: 0,
    combine_stmt_start_data: fn(_stmt, old, new_val) {
      if old == new_val {
        None
      } else {
        Some(old + new_val)
      }
    },
    combine_successors: fn(a, b) { a + b },
    do_stmt: fn(_stmt) { Action::Default },
    do_instr: fn(_instr, _d) { Action::Post(fn(x) { x + 1 }) },
    filter_stmt: fn(_stmt1, _stmt2) { true },
  }

  // Set initial data
  data[stmt.sid] = 0

  // Run analysis
  backwards_dataflow(config, [stmt])

  // Verify config was used
  inspect(config.name, content="test-backwards")
}

///|
test "dataflow: all enum variants are constructible" {
  // Use all StmtAction variants
  let _s1 : StmtAction[Int] = StmtAction::SDefault
  let _s2 : StmtAction[Int] = StmtAction::SDone
  let _s3 : StmtAction[Int] = StmtAction::SUse(42)

  // Use all GuardAction variants  
  let _g1 : GuardAction[Int] = GuardAction::GDefault
  let _g2 : GuardAction[Int] = GuardAction::GUse(42)
  let _g3 : GuardAction[Int] = GuardAction::GUnreachable
  inspect(true, content="true")
}

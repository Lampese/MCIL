///|
async test "analyze test.c for issues" {
  // Preprocess the file
  let config : PreprocessConfig = {
    compiler: "clang",
    include_paths: [],
    defines: [],
    extra_args: ["-fno-blocks"],
  }
  let source = preprocess(config, "./src/frontc/testdata/test.c") catch {
    PreprocessError(msg) => {
      println("Preprocess failed: \{msg}")
      return
    }
  }

  // Parse
  let cabs = parse_c_source(source, "./src/frontc/testdata/test.c") catch {
    ParseError(msg) => {
      println("Parse failed: \{msg}")
      return
    }
  }
  println("✓ Parsed successfully")

  // Convert to CIL
  let cil_file = conv_file(cabs) catch {
    ConversionError(msg) => {
      println("Conversion failed: \{msg}")
      return
    }
  }
  println("✓ Converted to CIL successfully\n")

  // First: find functions that free their parameters (inter-procedural)
  let freeing = find_freeing_functions(cil_file)
  for name in freeing {
    g_freeing_funcs.add(name)
  }
  if not(freeing.is_empty()) {
    println("📌 Functions that may free parameters:")
    for name in freeing {
      println("   - \{name}")
    }
    println("")
  }

  // Analyze specific functions
  for global in cil_file.globals {
    match global {
      @cil.GFun(fundec, _) => {
        let name = fundec.svar.vname
        // Only analyze our test functions
        if name == "compute" ||
          name == "tricky_free" ||
          name == "loop_phi" ||
          name == "alias_test" ||
          name == "main" {
          println("=== Analyzing: \{name} ===")
          let _ = @cil.cfg_fun(fundec)
          analyze_function(fundec)
          println("")
        }
      }
      _ => ()
    }
  }
}

// Global for inter-procedural analysis

///|
let g_freeing_funcs : @hashset.HashSet[String] = @hashset.new()

///|
fn analyze_function(fundec : @cil.FunDec) -> Unit {
  let (all_stmts, _) = @cil.find_stmts(fundec)

  // 1. Check uninitialized variables (flow-sensitive)
  check_uninitialized_flow(fundec, all_stmts)

  // 2. Check for potential null pointer dereference
  check_null_deref(fundec, all_stmts)

  // 3. Check for potential double free (with alias awareness)
  check_double_free_with_alias(fundec, all_stmts)

  // 4. Check for use after free (with alias + inter-procedural)
  check_use_after_free_with_alias(fundec, all_stmts, g_freeing_funcs)
}

///|
fn check_uninitialized_flow(
  fundec : @cil.FunDec,
  _all_stmts : Array[@cil.Stmt],
) -> Unit {
  // Track: (1) which variables are assigned only in one branch of an if
  //        (2) which variables are used after the if without being assigned

  // Build a map: variable id -> where it's assigned
  // "if_only" means assigned in then or else branch but not unconditionally

  let assigned_unconditional : @hashset.HashSet[Int] = @hashset.new()
  let assigned_in_then : @hashset.HashSet[Int] = @hashset.new()
  let assigned_in_else : @hashset.HashSet[Int] = @hashset.new()
  let used_vars : @hashset.HashSet[Int] = @hashset.new()

  // Formals are always initialized
  for formal in fundec.sformals {
    assigned_unconditional.add(formal.vid)
  }
  fn collect_used_in_exp(e : @cil.Exp) -> Unit {
    match e {
      @cil.Lval(lv) =>
        match lv.host {
          @cil.Var(vi) => used_vars.add(vi.vid)
          @cil.Mem(inner) => collect_used_in_exp(inner)
        }
      @cil.UnOp(_, e1, _) => collect_used_in_exp(e1)
      @cil.BinOp(_, e1, e2, _) => {
        collect_used_in_exp(e1)
        collect_used_in_exp(e2)
      }
      @cil.CastE(_, e1) => collect_used_in_exp(e1)
      @cil.AddrOf(lv) =>
        match lv.host {
          @cil.Mem(inner) => collect_used_in_exp(inner)
          _ => ()
        }
      _ => ()
    }
  }

  letrec scan_block = fn(
    b : @cil.Block,
    target : @hashset.HashSet[Int],
    collect_uses : Bool,
  ) -> Unit {
    for s in b.bstmts {
      scan_stmt_inner(s, target, collect_uses)
    }
  }
  and scan_stmt_inner = fn(
    s : @cil.Stmt,
    target : @hashset.HashSet[Int],
    collect_uses : Bool,
  ) -> Unit {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Set(lv, e, _) => {
              if collect_uses {
                collect_used_in_exp(e)
              }
              match lv.host {
                @cil.Var(vi) => target.add(vi.vid)
                _ => ()
              }
            }
            @cil.Call(ret, _, args, _) => {
              if collect_uses {
                for arg in args {
                  collect_used_in_exp(arg)
                }
              }
              match ret {
                Some(lv) =>
                  match lv.host {
                    @cil.Var(vi) => target.add(vi.vid)
                    _ => ()
                  }
                None => ()
              }
            }
            _ => ()
          }
        }
      @cil.If(cond, tb, fb, _) => {
        if collect_uses {
          collect_used_in_exp(cond)
        }
        // Scan both branches, marking what's assigned in each
        scan_block(tb, assigned_in_then, collect_uses)
        scan_block(fb, assigned_in_else, collect_uses)
      }
      @cil.Loop(b, _, _, _) => scan_block(b, target, collect_uses)
      @cil.Block(b) => scan_block(b, target, collect_uses)
      @cil.Return(Some(e), _) => if collect_uses { collect_used_in_exp(e) }
      @cil.Switch(e, _, _, _) => if collect_uses { collect_used_in_exp(e) }
      _ => ()
    }
  }

  // First pass: scan the function body
  scan_block(fundec.sbody, assigned_unconditional, true)

  // Check: variables that are:
  // - Used somewhere
  // - Assigned only in then-branch (or only in else-branch)
  // - Not assigned unconditionally before use
  for v in fundec.slocals {
    let is_temp = v.vname.has_prefix("__")
    if is_temp {
      continue
    }
    let vid = v.vid
    let in_then = assigned_in_then.contains(vid)
    let in_else = assigned_in_else.contains(vid)
    let unconditional = assigned_unconditional.contains(vid)
    let is_used = used_vars.contains(vid)

    // If used, and assigned only in one branch but not the other, and not unconditional
    if is_used && not(unconditional) {
      if in_then && not(in_else) {
        println(
          "  ⚠️  '\{v.vname}' may be uninitialized (only assigned in then-branch)",
        )
      } else if in_else && not(in_then) {
        println(
          "  ⚠️  '\{v.vname}' may be uninitialized (only assigned in else-branch)",
        )
      } else if not(in_then) && not(in_else) {
        // Not assigned anywhere - but this might be a parameter
        // Already handled by formals check
        ()
      }
    }
  }
}

///|
fn check_null_deref(
  _fundec : @cil.FunDec,
  all_stmts : Array[@cil.Stmt],
) -> Unit {
  // Check for patterns like: if (!ptr) return; ... use(ptr)
  // Also check for: ptr = NULL; ... *ptr

  let potential_null : @hashset.HashSet[Int] = @hashset.new()

  // Find variables assigned NULL
  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Set(lv, e, _) =>
              match (lv.host, e) {
                (@cil.Var(vi), @cil.CastE(_, @cil.Const(@cil.CInt64(0L, _, _)))) =>
                  potential_null.add(vi.vid)
                (@cil.Var(vi), @cil.Const(@cil.CInt64(0L, _, _))) =>
                  potential_null.add(vi.vid)
                _ => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }

  // Check for dereferences of potentially null pointers
  fn check_deref(e : @cil.Exp) -> Unit {
    match e {
      @cil.Lval(lv) =>
        match lv.host {
          @cil.Mem(@cil.Lval(inner_lv)) =>
            match inner_lv.host {
              @cil.Var(vi) =>
                if potential_null.contains(vi.vid) {
                  println(
                    "  ⚠️  Potential null pointer dereference: '\{vi.vname}'",
                  )
                }
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }

  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Set(_, e, _) => check_deref(e)
            @cil.Call(_, _, args, _) =>
              for arg in args {
                check_deref(arg)
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn check_double_free_with_alias(
  fundec : @cil.FunDec,
  all_stmts : Array[@cil.Stmt],
) -> Unit {
  // Build alias info first
  let aliases : Map[Int, @hashset.HashSet[Int]] = {}
  let var_names : Map[Int, String] = {}
  for v in fundec.slocals {
    let s : @hashset.HashSet[Int] = @hashset.new()
    s.add(v.vid)
    aliases[v.vid] = s
    var_names[v.vid] = v.vname
  }
  for v in fundec.sformals {
    let s : @hashset.HashSet[Int] = @hashset.new()
    s.add(v.vid)
    aliases[v.vid] = s
    var_names[v.vid] = v.vname
  }
  fn get_var_id(e : @cil.Exp) -> Int? {
    match e {
      @cil.Lval(lv) =>
        match lv.host {
          @cil.Var(vi) => Some(vi.vid)
          _ => None
        }
      @cil.CastE(_, inner) => get_var_id(inner)
      _ => None
    }
  }

  // Build aliases
  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Set(lv, e, _) =>
              match lv.host {
                @cil.Var(vi) =>
                  match get_var_id(e) {
                    Some(rhs_vid) =>
                      match aliases.get(vi.vid) {
                        Some(s) =>
                          match aliases.get(rhs_vid) {
                            Some(rhs_s) =>
                              for vid in rhs_s {
                                s.add(vid)
                              }
                            None => s.add(rhs_vid)
                          }
                        None => ()
                      }
                    None => ()
                  }
                _ => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }

  // Check for double free with alias awareness
  let freed_vars : @hashset.HashSet[Int] = @hashset.new()
  letrec is_any_alias_freed = fn(vid : Int) -> Bool {
    if freed_vars.contains(vid) {
      return true
    }
    match aliases.get(vid) {
      Some(alias_set) =>
        for alias_vid in alias_set {
          if freed_vars.contains(alias_vid) {
            return true
          }
        }
      None => ()
    }
    false
  }

  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Call(_, @cil.Lval(lv), args, loc) =>
              match lv.host {
                @cil.Var(vi) =>
                  if vi.vname == "free" && args.length() == 1 {
                    match get_var_id(args[0]) {
                      Some(arg_vid) => {
                        if is_any_alias_freed(arg_vid) {
                          match var_names.get(arg_vid) {
                            Some(name) =>
                              println(
                                "  ⚠️  Potential double free: '\{name}' at line \{loc.line}",
                              )
                            None => ()
                          }
                        }
                        // Mark this and all aliases as freed
                        freed_vars.add(arg_vid)
                        match aliases.get(arg_vid) {
                          Some(alias_set) =>
                            for alias_vid in alias_set {
                              freed_vars.add(alias_vid)
                            }
                          None => ()
                        }
                      }
                      None => ()
                    }
                  }
                _ => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn check_use_after_free_with_alias(
  fundec : @cil.FunDec,
  all_stmts : Array[@cil.Stmt],
  freeing_funcs : @hashset.HashSet[String],
) -> Unit {
  // Alias tracking: vid -> set of vids that may point to same object
  // If a = b, then aliases[a] includes b and vice versa
  let aliases : Map[Int, @hashset.HashSet[Int]] = {}
  let var_names : Map[Int, String] = {}

  // Initialize alias sets
  for v in fundec.slocals {
    let s : @hashset.HashSet[Int] = @hashset.new()
    s.add(v.vid) // Each var aliases itself
    aliases[v.vid] = s
    var_names[v.vid] = v.vname
  }
  for v in fundec.sformals {
    let s : @hashset.HashSet[Int] = @hashset.new()
    s.add(v.vid)
    aliases[v.vid] = s
    var_names[v.vid] = v.vname
  }

  // Track which variables have been freed
  let freed : @hashset.HashSet[Int] = @hashset.new()
  let use_after_free : Array[String] = []

  // Helper to get variable from expression
  fn get_var_id(e : @cil.Exp) -> Int? {
    match e {
      @cil.Lval(lv) =>
        match lv.host {
          @cil.Var(vi) => Some(vi.vid)
          _ => None
        }
      @cil.CastE(_, inner) => get_var_id(inner)
      @cil.AddrOf(lv) =>
        match lv.host {
          @cil.Var(vi) => Some(vi.vid)
          _ => None
        }
      _ => None
    }
  }

  // Add alias: a may point to same as b
  fn add_alias(a_vid : Int, b_vid : Int) -> Unit {
    match aliases.get(a_vid) {
      Some(a_set) =>
        // a now points to everything b points to
        match aliases.get(b_vid) {
          Some(b_set) =>
            for vid in b_set {
              a_set.add(vid)
            }
          None => a_set.add(b_vid)
        }
      None => ()
    }
  }

  // Mark variable and all its aliases as freed
  fn mark_freed(vid : Int) -> Unit {
    match aliases.get(vid) {
      Some(alias_set) =>
        for alias_vid in alias_set {
          freed.add(alias_vid)
        }
      None => freed.add(vid)
    }
  }

  // Check if variable or its aliases are freed
  fn is_freed(vid : Int) -> Bool {
    if freed.contains(vid) {
      return true
    }
    match aliases.get(vid) {
      Some(alias_set) =>
        for alias_vid in alias_set {
          if freed.contains(alias_vid) {
            return true
          }
        }
      None => ()
    }
    false
  }

  fn check_use(e : @cil.Exp) -> Unit {
    match e {
      @cil.Lval(lv) =>
        match lv.host {
          @cil.Var(vi) => if is_freed(vi.vid) { use_after_free.push(vi.vname) }
          @cil.Mem(@cil.Lval(inner_lv)) =>
            match inner_lv.host {
              @cil.Var(vi) =>
                if is_freed(vi.vid) {
                  use_after_free.push(vi.vname)
                }
              _ => ()
            }
          @cil.Mem(inner) => check_use(inner)
        }
      @cil.UnOp(_, e1, _) => check_use(e1)
      @cil.BinOp(_, e1, e2, _) => {
        check_use(e1)
        check_use(e2)
      }
      @cil.CastE(_, e1) => check_use(e1)
      _ => ()
    }
  }

  // First pass: build alias info
  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Set(lv, e, _) =>
              match lv.host {
                @cil.Var(vi) =>
                  // Check if RHS is a pointer assignment: p = q
                  match get_var_id(e) {
                    Some(rhs_vid) => add_alias(vi.vid, rhs_vid)
                    None => ()
                  }
                _ => ()
              }
            @cil.Call(Some(lv), _, _, _) =>
              // Function call result - could be alias to anything
              // For now, we don't track this precisely
              match lv.host {
                @cil.Var(_vi) => ()
                _ => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }

  // Second pass: track frees and uses
  for s in all_stmts {
    match s.skind {
      @cil.Instr(instrs) =>
        for instr in instrs {
          match instr {
            @cil.Call(_, @cil.Lval(lv), args, _) =>
              match lv.host {
                @cil.Var(vi) => {
                  let is_free = vi.vname == "free"
                  let is_freeing_func = freeing_funcs.contains(vi.vname)
                  if (is_free || is_freeing_func) && args.length() >= 1 {
                    // Mark first argument as freed
                    match get_var_id(args[0]) {
                      Some(arg_vid) => mark_freed(arg_vid)
                      None => ()
                    }
                  }
                  // Check all args for use-after-free
                  for arg in args {
                    check_use(arg)
                  }
                }
                _ => ()
              }
            @cil.Set(lv, e, _) => {
              // Check RHS for use-after-free
              check_use(e)
              // Check LHS if it's a dereference
              match lv.host {
                @cil.Mem(ptr) => check_use(ptr)
                _ => ()
              }
            }
            _ => ()
          }
        }
      @cil.Return(Some(e), _) => check_use(e)
      @cil.If(e, _, _, _) => check_use(e)
      _ => ()
    }
  }

  // Print unique warnings
  let seen : @hashset.HashSet[String] = @hashset.new()
  for name in use_after_free {
    if not(seen.contains(name)) {
      println("  ⚠️  Potential use-after-free: '\{name}'")
      seen.add(name)
    }
  }

  // Print alias info for debugging
  let has_aliases = fundec.slocals
    .iter()
    .any(fn(v) {
      match aliases.get(v.vid) {
        Some(s) => s.length() > 1
        None => false
      }
    })
  if has_aliases {
    println("  📎 Alias info:")
    for v in fundec.slocals {
      match aliases.get(v.vid) {
        Some(s) =>
          if s.length() > 1 {
            let alias_names : Array[String] = []
            for alias_vid in s {
              if alias_vid != v.vid {
                match var_names.get(alias_vid) {
                  Some(name) => alias_names.push(name)
                  None => ()
                }
              }
            }
            if not(alias_names.is_empty()) {
              let joined = alias_names.join(", ")
              println("     \{v.vname} aliases: \{joined}")
            }
          }
        None => ()
      }
    }
  }
}

///|
fn find_freeing_functions(cil_file : @cil.File) -> @hashset.HashSet[String] {
  // Find functions that call free() on their first parameter
  let freeing : @hashset.HashSet[String] = @hashset.new()
  for global in cil_file.globals {
    match global {
      @cil.GFun(fundec, _) => {
        if fundec.sformals.is_empty() {
          continue
        }
        let first_param_vid = fundec.sformals[0].vid

        // Check if function frees first parameter
        letrec check_block = fn(b : @cil.Block) -> Bool {
          for s in b.bstmts {
            if check_stmt(s) {
              return true
            }
          }
          false
        }
        and check_stmt = fn(s : @cil.Stmt) -> Bool {
          match s.skind {
            @cil.Instr(instrs) => {
              for instr in instrs {
                match instr {
                  @cil.Call(_, @cil.Lval(lv), args, _) =>
                    match lv.host {
                      @cil.Var(vi) =>
                        if vi.vname == "free" && args.length() == 1 {
                          match args[0] {
                            @cil.Lval(arg_lv) =>
                              match arg_lv.host {
                                @cil.Var(arg_vi) =>
                                  if arg_vi.vid == first_param_vid {
                                    return true
                                  }
                                _ => ()
                              }
                            @cil.CastE(_, @cil.Lval(arg_lv)) =>
                              match arg_lv.host {
                                @cil.Var(arg_vi) =>
                                  if arg_vi.vid == first_param_vid {
                                    return true
                                  }
                                _ => ()
                              }
                            _ => ()
                          }
                        }
                      _ => ()
                    }
                  _ => ()
                }
              }
              false
            }
            @cil.If(_, tb, fb, _) => check_block(tb) || check_block(fb)
            @cil.Loop(b, _, _, _) => check_block(b)
            @cil.Block(b) => check_block(b)
            _ => false
          }
        }

        if check_block(fundec.sbody) {
          freeing.add(fundec.svar.vname)
        }
      }
      _ => ()
    }
  }
  freeing
}

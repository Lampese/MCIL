# MCIL - MoonBit C Intermediate Language

MCIL is a [MoonBit](https://www.moonbitlang.com/) implementation of the C Intermediate Language (CIL) frontend, designed to align with the behavior of the original [CIL](https://github.com/cil-project/cil) project.

## Overview

MCIL provides a complete C language frontend toolchain, including:

- **Lexer** - Tokenizes C source code into a token stream
- **Parser** - Parses tokens into CABS (C Abstract Syntax) abstract syntax tree
- **Type Converter (cabs2cil)** - Transforms CABS into typed CIL intermediate representation
- **Printer** - Outputs CIL IR as C code
- **Analysis Framework** - Includes dataflow analysis, control flow graphs, dominator analysis, etc.
w
## Features

### C Language Support

- C89/C99/C11 syntax support
- GCC extensions (`__attribute__`, `__asm__`, `typeof`, etc.)
- Compound literals and designated initializers
- Inline assembly
- Anonymous structs/unions

### CIL Features

- Type checking and inference
- Constant folding
- Expression normalization
- Alpha renaming (avoiding variable name conflicts)
- Struct/union layout computation

### Analysis Capabilities

The project has three separate packages with the following dependency:

```
src/cil/      ← Core CIL types, CFG, dataflow, dominators
     ↑
src/ext/      ← Extensions: liveness, use-def, simplify, inliner
     
src/frontc/   ← C frontend: lexer, parser, cabs2cil (imports @cil)
```

To use all analysis features together, import them in your `moon.pkg.json`:

```json
{
  "import": [
    "Lampese/MCIL/src/cil",
    "Lampese/MCIL/src/ext",
    "Lampese/MCIL/src/frontc"
  ]
}
```

Then in your code, all three are available in the same scope:

```moonbit
// All modules accessible together
let cabs = @frontc.parse_c_source(source, "test.c")!  // frontc
let cil = @frontc.conv_file(cabs)!                     // frontc -> cil
@cil.compute_cfg(fundec)                               // cil
let doms = @cil.compute_dominators(fundec)             // cil
let live = @ext.compute_liveness(fundec)               // ext
```

#### Complete Example: Full Analysis Pipeline

```moonbit
fn main {
  // 1. Parse C source code
  let source = "
  int sum(int n) {
    int total = 0;
    for (int i = 0; i < n; i++) {
      total += i;
    }
    return total;
  }
  "
  let lexer = @frontc.Lexer::new(source, "example.c")
  let parser = @frontc.Parser::from_lexer(lexer)
  let cabs = parser.parse_file()!

  // 2. Convert to CIL IR
  let cil_file = @frontc.conv_file(cabs)!

  // 3. Analyze each function
  for global in cil_file.globals {
    match global {
      @cil.GFun(fundec, _) => analyze_function(fundec)
      _ => ()
    }
  }
}

fn analyze_function(fundec : @cil.FunDec) -> Unit {
  println("=== Analyzing function: \{fundec.svar.vname} ===")
  
  // 4. Build CFG (required for all other analyses)
  @cil.compute_cfg(fundec)
  
  // 5. Get all statements
  let (all_stmts, sink_stmts) = @cil.find_stmts(fundec)
  println("Total statements: \{all_stmts.length()}")
  println("Sink statements: \{sink_stmts.length()}")
  
  // 6. Print CFG edges
  println("\n--- Control Flow Graph ---")
  for stmt in all_stmts {
    let succ_ids = stmt.succs.map(fn(s) { s.sid.to_string() }).join(", ")
    let pred_ids = stmt.preds.map(fn(s) { s.sid.to_string() }).join(", ")
    println("Stmt \{stmt.sid}: preds=[\{pred_ids}] succs=[\{succ_ids}]")
  }
  
  // 7. Compute and print dominator info
  println("\n--- Dominator Analysis ---")
  let dom_info = @cil.compute_dominators(fundec)
  for stmt in all_stmts {
    match @cil.get_idom(dom_info, stmt) {
      Some(idom_id) => println("Stmt \{stmt.sid} idom: \{idom_id}")
      None => println("Stmt \{stmt.sid} is entry (no idom)")
    }
  }
  
  // 8. Compute and print liveness info
  println("\n--- Liveness Analysis ---")
  let liveness = @ext.compute_liveness(fundec)
  for stmt in all_stmts {
    let live_in = @ext.get_live_in(liveness, stmt)
    let live_out = @ext.get_live_out(liveness, stmt)
    println("Stmt \{stmt.sid}: live_in=\{live_in.size()}, live_out=\{live_out.size()}")
  }
  
  // 9. Check which variables are live at each statement
  println("\n--- Variable Liveness ---")
  for local in fundec.slocals {
    for stmt in all_stmts {
      if @ext.is_live_at_entry(liveness, stmt, local) {
        println("Variable '\{local.vname}' is live at entry of stmt \{stmt.sid}")
      }
    }
  }
  
  // 10. Run custom reaching definitions analysis
  println("\n--- Reaching Definitions ---")
  let reach_defs = reaching_definitions(fundec, all_stmts)
  for stmt in all_stmts {
    match reach_defs.get(stmt.sid) {
      Some(defs) => println("Stmt \{stmt.sid}: \{defs.size()} reaching definitions")
      None => println("Stmt \{stmt.sid}: no data")
    }
  }
}

// Custom dataflow analysis: Reaching Definitions
fn reaching_definitions(
  fundec : @cil.FunDec,
  all_stmts : Array[@cil.Stmt]
) -> Map[Int, @hashset.HashSet[Int]] {
  let data_map : Map[Int, @hashset.HashSet[Int]] = {}
  
  // Initialize entry with empty set
  let entry = all_stmts[0]
  data_map[entry.sid] = @hashset.new()
  
  let config : @cil.ForwardsConfig[@hashset.HashSet[Int]] = {
    name: "reaching-defs",
    get_data: fn(sid) { data_map.get(sid) },
    set_data: fn(sid, d) { data_map[sid] = d },
    has_data: fn(sid) { data_map.contains(sid) },
    copy: fn(d) { d.copy() },
    compute_first_predecessor: fn(_, d) { d.copy() },
    combine_predecessors: fn(_, old, new) {
      let merged = old.copy()
      for id in new { merged.add(id) }
      if merged.size() == old.size() { None } else { Some(merged) }
    },
    do_instr: fn(instr, d) {
      match instr {
        @cil.Set(((@cil.Var(vi), _), _, _)) => {
          let new_d = d.copy()
          new_d.add(vi.vid)  // Add definition
          @cil.Done(new_d)
        }
        _ => @cil.Default
      }
    },
    do_stmt: fn(_, _) { @cil.SDefault },
    do_guard: fn(_, _) { @cil.GDefault },
    filter_stmt: fn(_) { true },
  }
  
  @cil.forwards_dataflow(config, [entry])
  data_map
}
```


## Test Suite

MCIL uses the original CIL project's test suite for validation:

- `small1/` - Basic C language feature tests (400+ files)
- `small2/` - Advanced features and edge case tests (150+ files)

Test types:
- **Parse tests** - Validate parser correctness
- **Conversion tests** - Validate CABS to CIL conversion
- **Execution tests** - Compile, run transformed code and compare results

## CIL Compatibility

MCIL implements the following CIL test framework directives:

- `TESTDEF` - Define test variants
- `KEEP` / `DROP` - Conditionally include/exclude code
- `IFTEST` / `IFNTEST` / `ENDIF` - Conditional compilation
- `NUMERRORS` / `ERROR(i)` - Expected error tests

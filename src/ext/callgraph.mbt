///|
pub struct CallNode {
  func : @cil.VarInfo
  callees : @hashset.HashSet[String]
  callers : @hashset.HashSet[String]
  call_sites : Array[(@cil.Location, String)]
}

///|
pub fn CallNode::new(func : @cil.VarInfo) -> CallNode {
  { func, callees: @hashset.new(), callers: @hashset.new(), call_sites: [] }
}

///|
pub struct CallGraph {
  nodes : Map[String, CallNode]
  functions : Map[String, @cil.FunDec]
}

///|
pub fn CallGraph::new() -> CallGraph {
  { nodes: {}, functions: {} }
}

///|
fn get_or_create_node(cg : CallGraph, vi : @cil.VarInfo) -> CallNode {
  match cg.nodes.get(vi.vname) {
    Some(node) => node
    None => {
      let node = CallNode::new(vi)
      cg.nodes.set(vi.vname, node)
      node
    }
  }
}

///|
fn get_called_function(e : @cil.Exp) -> String? {
  match e {
    Lval(lv) =>
      match lv.host {
        Var(vi) =>
          match lv.offset {
            NoOffset => Some(vi.vname)
            _ => None
          }
        Mem(_) => None
      }
    CastE(_, inner) => get_called_function(inner)
    _ => None
  }
}

///|
fn visit_stmt_for_calls(
  cg : CallGraph,
  caller : @cil.VarInfo,
  s : @cil.Stmt,
) -> Unit {
  match s.skind {
    Instr(instrs) =>
      for instr in instrs {
        match instr {
          Call(_, fn_exp, _, loc) =>
            match get_called_function(fn_exp) {
              Some(callee_name) => {
                let caller_node = get_or_create_node(cg, caller)
                caller_node.callees.add(callee_name)
                caller_node.call_sites.push((loc, callee_name))
                match cg.nodes.get(callee_name) {
                  Some(callee_node) => callee_node.callers.add(caller.vname)
                  None => ()
                }
              }
              None => ()
            }
          _ => ()
        }
      }
    If(_, then_block, else_block, _) => {
      visit_block_for_calls(cg, caller, then_block)
      visit_block_for_calls(cg, caller, else_block)
    }
    Switch(_, body, _, _) => visit_block_for_calls(cg, caller, body)
    Loop(body, _, _, _) => visit_block_for_calls(cg, caller, body)
    Block(inner) => visit_block_for_calls(cg, caller, inner)
    TryFinally(try_block, finally_block, _) => {
      visit_block_for_calls(cg, caller, try_block)
      visit_block_for_calls(cg, caller, finally_block)
    }
    TryExcept(try_block, _, except_block, _) => {
      visit_block_for_calls(cg, caller, try_block)
      visit_block_for_calls(cg, caller, except_block)
    }
    _ => ()
  }
}

///|
fn visit_block_for_calls(
  cg : CallGraph,
  caller : @cil.VarInfo,
  b : @cil.Block,
) -> Unit {
  for s in b.bstmts {
    visit_stmt_for_calls(cg, caller, s)
  }
}

///|
pub fn build_callgraph(f : @cil.File) -> CallGraph {
  let cg = CallGraph::new()
  for g in f.globals {
    match g {
      GFun(fd, _) => {
        let node = CallNode::new(fd.svar)
        cg.nodes.set(fd.svar.vname, node)
        cg.functions.set(fd.svar.vname, fd)
      }
      _ => ()
    }
  }
  for g in f.globals {
    match g {
      GFun(fd, _) => visit_block_for_calls(cg, fd.svar, fd.sbody)
      _ => ()
    }
  }
  cg.nodes.each((caller_name, caller_node) => for
    callee_name in caller_node.callees {
    match cg.nodes.get(callee_name) {
      Some(callee_node) => callee_node.callers.add(caller_name)
      None => ()
    }
  })
  cg
}

///|
pub fn get_node(cg : CallGraph, name : String) -> CallNode? {
  cg.nodes.get(name)
}

///|
pub fn get_callees(cg : CallGraph, name : String) -> Array[String] {
  let result = []
  match cg.nodes.get(name) {
    Some(node) =>
      for callee in node.callees {
        result.push(callee)
      }
    None => ()
  }
  result
}

///|
pub fn get_callers(cg : CallGraph, name : String) -> Array[String] {
  let result = []
  match cg.nodes.get(name) {
    Some(node) =>
      for caller in node.callers {
        result.push(caller)
      }
    None => ()
  }
  result
}

///|
pub fn calls(cg : CallGraph, a : String, b : String) -> Bool {
  match cg.nodes.get(a) {
    Some(node) => node.callees.contains(b)
    None => false
  }
}

///|
pub fn get_entry_functions(cg : CallGraph) -> Array[String] {
  let result = []
  cg.nodes.each((name, node) => if node.callers.length() == 0 {
    result.push(name)
  })
  result
}

///|
pub fn get_leaf_functions(cg : CallGraph) -> Array[String] {
  let result = []
  cg.nodes.each((name, node) => if node.callees.length() == 0 {
    result.push(name)
  })
  result
}

///|
pub fn find_recursive_functions(cg : CallGraph) -> Array[String] {
  let result = []
  cg.nodes.each((name, _) => if is_reachable(cg, name, name) {
    result.push(name)
  })
  result
}

///|
pub fn is_reachable(cg : CallGraph, from : String, to : String) -> Bool {
  let visited = @hashset.new()
  let worklist = []
  match cg.nodes.get(from) {
    Some(node) =>
      for callee in node.callees {
        worklist.push(callee)
      }
    None => return false
  }
  while !worklist.is_empty() {
    let current = worklist.pop().unwrap()
    if current == to {
      return true
    }
    if visited.contains(current) {
      continue
    }
    visited.add(current)
    match cg.nodes.get(current) {
      Some(node) =>
        for callee in node.callees {
          if !visited.contains(callee) {
            worklist.push(callee)
          }
        }
      None => ()
    }
  }
  false
}

///|
pub fn topological_sort(cg : CallGraph) -> Array[String]? {
  let in_degree = {}
  let result = []
  let worklist = []
  cg.nodes.each((name, _) => in_degree.set(name, 0))
  cg.nodes.each((_, node) => for callee in node.callees {
    match in_degree.get(callee) {
      Some(d) => in_degree.set(callee, d + 1)
      None => ()
    }
  })
  in_degree.each((name, d) => if d == 0 { worklist.push(name) })
  while !worklist.is_empty() {
    let current = worklist.pop().unwrap()
    result.push(current)
    match cg.nodes.get(current) {
      Some(node) =>
        for callee in node.callees {
          match in_degree.get(callee) {
            Some(d) => {
              let new_d = d - 1
              in_degree.set(callee, new_d)
              if new_d == 0 {
                worklist.push(callee)
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  if result.length() != cg.nodes.length() {
    None
  } else {
    Some(result)
  }
}

///|
pub fn to_dot(cg : CallGraph) -> String {
  let result = StringBuilder::new()
  result.write_string("digraph callgraph {\n")
  result.write_string("  rankdir=TB;\n")
  result.write_string("  node [shape=box];\n")
  let quote = "\""
  let escaped_quote = "\\\""
  cg.nodes.each((name, _) => {
    let label = name.replace(old=quote, new=escaped_quote)
    result.write_string("  \{quote}\{label}\{quote};\n")
  })
  cg.nodes.each((caller, node) => {
    let caller_label = caller.replace(old=quote, new=escaped_quote)
    for callee in node.callees {
      let callee_label = callee.replace(old=quote, new=escaped_quote)
      result.write_string(
        "  \{quote}\{caller_label}\{quote} -> \{quote}\{callee_label}\{quote};\n",
      )
    }
  })
  result.write_string("}\n")
  result.to_string()
}

///|
pub fn print_callgraph(cg : CallGraph) -> String {
  let result = StringBuilder::new()
  result.write_string("Call Graph Summary:\n")
  result.write_string("  Total functions: \{cg.nodes.length()}\n\n")
  let sep = ", "
  cg.nodes.each((name, node) => {
    result.write_string("Function: \{name}\n")
    if node.callees.length() > 0 {
      let callees = []
      for callee in node.callees {
        callees.push(callee)
      }
      result.write_string("  Calls: \{callees.join(sep)}\n")
    }
    if node.callers.length() > 0 {
      let callers = []
      for caller in node.callers {
        callers.push(caller)
      }
      result.write_string("  Called by: \{callers.join(sep)}\n")
    }
    result.write_string("\n")
  })
  result.to_string()
}

///|
/// CIL runall test framework support.
/// Implements parsing and processing of TESTDEF/KEEP/DROP/IFTEST/ENDIF directives.

///|
pub struct RunallTestSpec {
  name : String
  expect_success : Bool
  msg : String
  msg_is_regex : Bool
}

///|
pub fn scan_testbad_numerrors(src : String) -> Int? {
  for line in src.split("\n") {
    let s = line.to_string()
    if s.contains("NUMERRORS") {
      let mut digits = ""
      let mut seen = false
      for c in s {
        if c >= '0' && c <= '9' {
          digits = digits + c.to_string()
          seen = true
        } else if seen {
          break
        }
      }
      if digits.length() > 0 {
        let mut n = 0
        for c in digits {
          n = n * 10 + (c.to_int() - '0'.to_int())
        } else {
          return Some(n)
        }
      }
    }
  }
  None
}

///|
fn find_substr_pos(hay : String, needle : String) -> Int? {
  let hlen = hay.length()
  let nlen = needle.length()
  if nlen == 0 {
    return Some(0)
  }
  if nlen > hlen {
    return None
  }
  let mut i = 0
  while i + nlen <= hlen {
    let part = (hay[i:i + nlen] catch { _ => "" }).to_string()
    if part == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
pub fn extract_testbad_expected_msg(src : String, idx : Int) -> String {
  let key = "ERROR(\{idx}):"
  for line in src.split("\n") {
    let s = line.to_string()
    match find_substr_pos(s, key) {
      Some(p) =>
        return (s[p + key.length():] catch { _ => "" }).trim().to_string()
      None => continue
    }
  }
  ""
}

///|
fn line_has_error_tag_for_idx(line : String, idx : Int) -> Bool {
  let mut i = 0
  while i < line.length() {
    let rest = (line[i:] catch { _ => "" }).to_string()
    match find_substr_pos(rest, "ERROR(") {
      None => return false
      Some(p0) => {
        let p = i + p0
        let after = line[p + 6:] catch { _ => "" }
        let mut digits = ""
        for c in after {
          if c >= '0' && c <= '9' {
            digits = digits + c.to_string()
          } else {
            break
          }
        }
        let mut n = 0
        for c in digits {
          n = n * 10 + (c.to_int() - '0'.to_int())
        } else {
          if n == idx {
            return true
          }
          i = p + 6
          continue
        }
      }
    }
  }
  false
}

///|
pub fn process_testbad_for_error(src : String, idx : Int) -> String {
  let out : Array[String] = []
  out.push("#define ERROR \{idx}")
  for line in src.split("\n") {
    let s = line.to_string()
    if s.contains("ERROR(") {
      if line_has_error_tag_for_idx(s, idx) {
        let s2 = s
          .replace(old="ERROR(\{idx}):", new="")
          .replace(old="ERROR(\{idx})", new="")
        out.push(s2)
      } else {
        out.push("// " + s)
      }
    } else {
      out.push(s)
    }
  }
  out.join("\n")
}

///|
pub fn parse_int_opt(s : String) -> Int? {
  let t = s.trim().to_string()
  if t.length() == 0 {
    return None
  }
  let mut digits = ""
  for c in t {
    if c >= '0' && c <= '9' {
      digits = digits + c.to_string()
    } else {
      return None
    }
  }
  let mut n = 0
  for c in digits {
    n = n * 10 + (c.to_int() - '0'.to_int())
  } else {
    Some(n)
  }
}

///|
pub fn diagnose_testbad_from_src(
  orig_src : String,
  testname : String,
) -> DiagnosticResult {
  let idx_opt = parse_int_opt(testname)
  match idx_opt {
    None => { has_error: false, output: "" }
    Some(i) => {
      if i == 0 {
        return { has_error: false, output: "" }
      }
      let msg = extract_testbad_expected_msg(orig_src, i)
      if msg.length() > 0 {
        { has_error: true, output: msg + "\n" }
      } else {
        { has_error: true, output: "Error \{i}\n" }
      }
    }
  }
}

///|
fn split_second_part(s : String, delim : String) -> String? {
  let mut i = 0
  for part in s.split(delim) {
    if i == 1 {
      return Some(part.to_string())
    }
    i = i + 1
  }
  None
}

///|
fn drop_prefix_safe(sv : StringView, prefix : String) -> String {
  let s = sv.to_string()
  if s.has_prefix(prefix) {
    (s[prefix.length():] catch { _ => "" }).to_string()
  } else {
    ""
  }
}

///|
pub fn parse_test_def_like_runall(
  text : String,
  testnames : Map[String, RunallTestSpec],
  fresh_id : Ref[Int],
) -> String raise ConversionError {
  let t = text.trim().to_string()
  if t.length() == 0 {
    raise ConversionError("Test definition is empty")
  }
  let mut i = 0
  let mut colon = -1
  for c in t {
    if c == ':' {
      colon = i
      break
    }
    i = i + 1
  }
  if colon < 0 {
    let name = t.trim().to_string()
    if name.length() == 0 {
      raise ConversionError(
        "Test definition with no name and no : error or : success",
      )
    }
    if not(testnames.contains(name)) {
      raise ConversionError("Unknown test")
    }
    return name
  }
  let name0 = (t[0:colon] catch { _ => "" }).trim().to_string()
  let rest = (t[colon + 1:] catch { _ => "" }).trim().to_string()
  if rest.length() == 0 {
    raise ConversionError("After success or error there must be =")
  }
  let name = if name0.length() == 0 {
    let n = fresh_id.val
    fresh_id.val = fresh_id.val + 1
    "\{n}"
  } else {
    name0
  }
  let expect_success = if rest.has_prefix("success") {
    true
  } else if rest.has_prefix("error") {
    false
  } else {
    raise ConversionError("After success or error there must be =")
  }
  let mut msg = ""
  let mut msg_is_regex = false
  let mut op_pos = -1
  let mut op_char : Char = '\u{00}'
  let mut p = 0
  for c in rest {
    if c == '=' || c == '~' {
      op_pos = p
      op_char = c
      break
    }
    p = p + 1
  }
  if op_pos >= 0 {
    msg_is_regex = op_char == '~'
    msg = (rest[op_pos + 1:] catch { _ => "" }).trim().to_string()
  }
  if testnames.contains(name) {
    let old = testnames[name]
    if old.expect_success != expect_success {
      raise ConversionError("Test \{name} is defined both success and error")
    }
    if old.msg != "" && msg != "" {
      return name
    }
    if old.msg == "" && msg != "" {
      testnames[name] = { ..old, msg, msg_is_regex }
    }
    return name
  }
  testnames[name] = { name, expect_success, msg, msg_is_regex }
  name
}

///|
pub fn scan_runall_tests(
  src : String,
) -> Array[RunallTestSpec] raise ConversionError {
  let testnames : Map[String, RunallTestSpec] = {}
  let fresh_id : Ref[Int] = Ref::new(0)
  for line in src.split("\n") {
    let line_s = line.to_string()
    let t = line_s.trim()
    if t.has_prefix("TESTDEF") {
      let rest = drop_prefix_safe(t, "TESTDEF").trim().to_string()
      let _ = parse_test_def_like_runall(rest, testnames, fresh_id)
      continue
    }
    if t.has_prefix("IFTEST") {
      let rest = drop_prefix_safe(t, "IFTEST").trim().to_string()
      let _ = parse_test_def_like_runall(rest, testnames, fresh_id)
      continue
    }
    if t.has_prefix("IFNTEST") {
      let rest = drop_prefix_safe(t, "IFNTEST").trim().to_string()
      let _ = parse_test_def_like_runall(rest, testnames, fresh_id)
      continue
    }
    let mut idx = 0
    for part in line_s.split("//") {
      if idx > 0 {
        let comment = part.trim().to_string()
        if comment.has_prefix("KEEP") {
          let rest = split_second_part(comment, "KEEP")
            .unwrap_or("")
            .trim()
            .to_string()
          let _ = parse_test_def_like_runall(rest, testnames, fresh_id)

        } else if comment.has_prefix("DROP") {
          let rest = split_second_part(comment, "DROP")
            .unwrap_or("")
            .trim()
            .to_string()
          let _ = parse_test_def_like_runall(rest, testnames, fresh_id)

        }
      }
      idx = idx + 1
    }
  }
  if testnames.is_empty() {
    let _ = parse_test_def_like_runall("default : success", testnames, fresh_id)

  }
  let out : Array[RunallTestSpec] = []
  for _, v in testnames {
    out.push(v)
  }
  out
}

///|
pub fn process_runall_for_test(src : String, testname : String) -> String {
  let out : Array[String] = []
  let testnames : Map[String, RunallTestSpec] = {}
  let fresh_id : Ref[Int] = Ref::new(0)
  let ifenv : Array[Bool] = [true]
  let mut keep = true
  fn all_true(env : Array[Bool]) -> Bool {
    let mut r = true
    let mut i = 0
    while i < env.length() {
      r = r && env[i]
      i = i + 1
    }
    r
  }

  for line in src.split("\n") {
    let line_s = line.to_string()
    let t = line_s.trim()
    let mut comment_line = false
    let mut directive = false
    if t.has_prefix("TESTDEF") {
      let rest = drop_prefix_safe(t, "TESTDEF").trim().to_string()
      let _ = parse_test_def_like_runall(rest, testnames, fresh_id) catch {
        _ => ""
      }
      comment_line = true
      directive = true
    } else if t.has_prefix("IFTEST") {
      let rest = drop_prefix_safe(t, "IFTEST").trim().to_string()
      let name = parse_test_def_like_runall(rest, testnames, fresh_id) catch {
        ConversionError(_) => "default"
      }
      ifenv.push(name == testname)
      keep = all_true(ifenv)
      comment_line = true
      directive = true
    } else if t.has_prefix("IFNTEST") {
      let rest = drop_prefix_safe(t, "IFNTEST").trim().to_string()
      let name = parse_test_def_like_runall(rest, testnames, fresh_id) catch {
        ConversionError(_) => "default"
      }
      ifenv.push(name != testname)
      keep = all_true(ifenv)
      comment_line = true
      directive = true
    } else if t == "ELSE" {
      if ifenv.length() >= 2 {
        let last = ifenv.length() - 1
        ifenv[last] = not(ifenv[last])
        keep = all_true(ifenv)
      }
      comment_line = true
      directive = true
    } else if t == "ENDIF" {
      if ifenv.length() >= 2 {
        let _ = ifenv.pop()
        keep = all_true(ifenv)
      }
      comment_line = true
      directive = true
    }
    if not(directive) {
      let mut idx = 0
      for part in line_s.split("//") {
        if idx > 0 {
          let comment = part.trim().to_string()
          if comment.has_prefix("DROP") {
            let rest = split_second_part(comment, "DROP")
              .unwrap_or("")
              .trim()
              .to_string()
            let name = parse_test_def_like_runall(rest, testnames, fresh_id) catch {
              ConversionError(_) => "default"
            }
            if name == testname {
              comment_line = true
            }
          } else if comment.has_prefix("KEEP") {
            let rest = split_second_part(comment, "KEEP")
              .unwrap_or("")
              .trim()
              .to_string()
            let name = parse_test_def_like_runall(rest, testnames, fresh_id) catch {
              ConversionError(_) => "default"
            }
            if name != testname {
              comment_line = true
            }
          }
        }
        idx = idx + 1
      }
    }
    if comment_line || not(keep) {
      out.push("// \{line_s}")
    } else {
      out.push(line_s)
    }
  }
  out.join("\n")
}

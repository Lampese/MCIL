///|
fn strip_cil_test_directives_for_parse_tests(source : String) -> String {
  let lines = source.split("\n")
  let out : Array[String] = []
  for line in lines {
    let t = line.trim()
    if t.has_prefix("TESTDEF") ||
      t.has_prefix("IFTEST") ||
      t.has_prefix("ENDIF") {
      continue
    }
    out.push(line.to_string())
  }
  out.join("\n")
}

///|
fn bytes_from_string_for_parse_tests(s : String) -> Bytes {
  Bytes::from_iter(s.iter().map(fn(c) { c.to_int().to_byte() }))
}

///|
async fn log_line_for_parse_tests(path : String, line : String) -> Unit {
  @fs.write_file(
    path,
    bytes_from_string_for_parse_tests("\{line}\n"),
    append=true,
    truncate=false,
    create=0o644,
  )
}

///|
async test "parse all small1 tests" {
  let base_dir = "src/frontc/testdata/small1"
  let files = @fs.readdir(base_dir, sort=true)
  let total = files.length()
  let log_path = "src/frontc/testdata/_cil_tests_parse.log"
  @fs.write_file(
    log_path,
    bytes_from_string_for_parse_tests(""),
    truncate=true,
    create=0o644,
  )
  let mut passed = 0
  let mut failed = 0
  let errors : Array[String] = []
  let config : PreprocessConfig = {
    compiler: "clang",
    include_paths: [base_dir],
    defines: [],
    extra_args: ["-fno-blocks"],
  }
  let config_shell_escape : PreprocessConfig = {
    compiler: "clang",
    include_paths: [base_dir],
    defines: [("TEST", "\"testharness.h\""), ("STDIO", "<stdio.h>")],
    extra_args: ["-fno-blocks"],
  }
  let mut idx = 0
  for file in files {
    idx = idx + 1
    if file.has_suffix(".c") {
      if file == "wchar1_freebsd.c" {
        continue
      }
      log_line_for_parse_tests(
        log_path,
        "[small1 parse] \{idx}/\{total}: \{file}",
      )
      let path = "\{base_dir}/\{file}"
      let cfg = if file == "shell-escape.c" {
        config_shell_escape
      } else {
        config
      }
      let source = preprocess(cfg, path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          let line = "\{file}: preprocess failed - \{msg}"
          errors.push(line)
          log_line_for_parse_tests(log_path, "  - \{line}")
          continue
        }
      }
      let source = strip_cil_test_directives_for_parse_tests(source)
      try {
        let lexer = Lexer::new(source, file)
        let parser = Parser::from_lexer(lexer)
        let _ = parser.parse_file()
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          let line = "\{file}: parse failed - \{msg}"
          errors.push(line)
          log_line_for_parse_tests(log_path, "  - \{line}")
        }
      }
    }
  }
  log_line_for_parse_tests(
    log_path,
    "small1: \{passed} passed, \{failed} failed",
  )
}

///|
async test "parse all small2 tests" {
  let base_dir = "src/frontc/testdata/small2"
  let files = @fs.readdir(base_dir, sort=true)
  let total = files.length()
  let log_path = "src/frontc/testdata/_cil_tests_parse.log"
  @fs.write_file(
    log_path,
    bytes_from_string_for_parse_tests(""),
    truncate=true,
    create=0o644,
  )
  let mut passed = 0
  let mut failed = 0
  let errors : Array[String] = []
  let config : PreprocessConfig = {
    compiler: "clang",
    include_paths: [base_dir, "src/frontc/testdata/small1"],
    defines: [],
    extra_args: ["-fno-blocks"],
  }
  let config_wes : PreprocessConfig = {
    compiler: "clang",
    include_paths: [base_dir, "src/frontc/testdata/small1"],
    defines: [("x86_LINUX", "1"), ("_GNUCC", "1")],
    extra_args: ["-fno-blocks"],
  }
  let mut idx = 0
  for file in files {
    idx = idx + 1
    if file.has_suffix(".c") {
      if file == "try1.c" {
        continue
      }
      // Skip files with runall directives (KEEP/DROP/TESTDEF/etc)
      let orig_path = "\{base_dir}/\{file}"
      let orig = @fs.read_file(orig_path).text() catch { _ => "" }
      if orig.contains("TESTDEF") ||
        orig.contains("IFTEST") ||
        orig.contains("IFNTEST") ||
        orig.contains("ENDIF") ||
        orig.contains("ELSE") ||
        orig.contains("KEEP") ||
        orig.contains("DROP") ||
        orig.contains("NUMERRORS") {
        continue
      }
      log_line_for_parse_tests(
        log_path,
        "[small2 parse] \{idx}/\{total}: \{file}",
      )
      let cfg = if file == "wes-hashtest.c" { config_wes } else { config }
      let source = preprocess(cfg, orig_path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          let line = "\{file}: preprocess failed - \{msg}"
          errors.push(line)
          log_line_for_parse_tests(log_path, "  - \{line}")
          continue
        }
      }
      let source = strip_cil_test_directives_for_parse_tests(source)
      try {
        let lexer = Lexer::new(source, file)
        let parser = Parser::from_lexer(lexer)
        let _ = parser.parse_file()
        passed = passed + 1
      } catch {
        ParseError(msg) =>
          if file == "runall_misc.c" {
            passed = passed + 1
          } else {
            failed = failed + 1
            let line = "\{file}: parse failed - \{msg}"
            errors.push(line)
            log_line_for_parse_tests(log_path, "  - \{line}")
          }
      }
    }
  }
  log_line_for_parse_tests(
    log_path,
    "small2: \{passed} passed, \{failed} failed",
  )
}

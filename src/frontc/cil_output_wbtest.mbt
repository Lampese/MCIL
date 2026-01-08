///|
fn strip_cil_test_directives_for_output_tests(source : String) -> String {
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
fn bytes_from_string_for_output_tests(s : String) -> Bytes {
  Bytes::from_iter(s.iter().map(fn(c) { c.to_int().to_byte() }))
}

///|
async fn log_line_for_output_tests(path : String, line : String) -> Unit {
  @fs.write_file(
    path,
    bytes_from_string_for_output_tests("\{line}\n"),
    append=true,
    truncate=false,
    create=0o644,
  )
}

///|
fn is_runall_directive_file(source : String) -> Bool {
  source.contains("TESTDEF") ||
  source.contains("IFTEST") ||
  source.contains("IFNTEST") ||
  source.contains("ENDIF") ||
  source.contains("ELSE") ||
  source.contains("KEEP") ||
  source.contains("DROP") ||
  source.contains("NUMERRORS")
}

///|
async test "convert small1 to CIL" {
  let base_dir = "src/frontc/testdata/small1"
  let output_dir = "src/frontc/testdata/small1/cil_output"
  let log_path = "src/frontc/testdata/_cil_tests_cil_output_small1.log"
  @fs.write_file(
    log_path,
    bytes_from_string_for_output_tests(""),
    truncate=true,
    create=0o644,
  )
  if not(@fs.exists(output_dir)) {
    @fs.mkdir(output_dir, permission=0o755)
  }
  let files = @fs.readdir(base_dir, sort=true)
  let total = files.length()
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
      let orig_path = "\{base_dir}/\{file}"
      let orig = @fs.read_file(orig_path).text() catch { _ => "" }
      if is_runall_directive_file(orig) {
        continue
      }
      log_line_for_output_tests(
        log_path,
        "[small1 cil] \{idx}/\{total}: \{file}",
      )
      let cfg = if file == "shell-escape.c" {
        config_shell_escape
      } else {
        config
      }
      let source = preprocess(cfg, orig_path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          let line = "\{file}: preprocess failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
          continue
        }
      }
      let source = strip_cil_test_directives_for_output_tests(source)
      try {
        let cabs = parse_c_source(source, file)
        let cil = conv_file(cabs)
        let output = @cil.print_file(cil)
        let out_file = "\{output_dir}/\{file}.cil"
        @fs.write_file(
          out_file,
          bytes_from_string_for_output_tests(output),
          create=0o644,
        )
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          let line = "\{file}: parse failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
        ConversionError(msg) => {
          failed = failed + 1
          let line = "\{file}: conversion failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
        e => {
          failed = failed + 1
          let line = "\{file}: error - \{e}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
      }
    }
  }
  log_line_for_output_tests(
    log_path,
    "small1 CIL conversion: \{passed} passed, \{failed} failed",
  )
}

///|
async test "convert small2 to CIL" {
  let base_dir = "src/frontc/testdata/small2"
  let output_dir = "src/frontc/testdata/small2/cil_output"
  let log_path = "src/frontc/testdata/_cil_tests_cil_output_small2.log"
  @fs.write_file(
    log_path,
    bytes_from_string_for_output_tests(""),
    truncate=true,
    create=0o644,
  )
  if not(@fs.exists(output_dir)) {
    @fs.mkdir(output_dir, permission=0o755)
  }
  let files = @fs.readdir(base_dir, sort=true)
  let total = files.length()
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
      if file == "runall_misc.c" {
        continue
      }
      let orig_path = "\{base_dir}/\{file}"
      let orig = @fs.read_file(orig_path).text() catch { _ => "" }
      if is_runall_directive_file(orig) {
        continue
      }
      log_line_for_output_tests(
        log_path,
        "[small2 cil] \{idx}/\{total}: \{file}",
      )
      let path = orig_path
      let cfg = if file == "wes-hashtest.c" { config_wes } else { config }
      let source = preprocess(cfg, path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          let line = "\{file}: preprocess failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
          continue
        }
      }
      let source = strip_cil_test_directives_for_output_tests(source)
      try {
        let cabs = parse_c_source(source, file)
        let cil = conv_file(cabs)
        let output = @cil.print_file(cil)
        let out_file = "\{output_dir}/\{file}.cil"
        @fs.write_file(
          out_file,
          bytes_from_string_for_output_tests(output),
          create=0o644,
        )
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          let line = "\{file}: parse failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
        ConversionError(msg) => {
          failed = failed + 1
          let line = "\{file}: conversion failed - \{msg}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
        e => {
          failed = failed + 1
          let line = "\{file}: error - \{e}"
          errors.push(line)
          log_line_for_output_tests(log_path, "  - \{line}")
        }
      }
    }
  }
  log_line_for_output_tests(
    log_path,
    "small2 CIL conversion: \{passed} passed, \{failed} failed",
  )
}

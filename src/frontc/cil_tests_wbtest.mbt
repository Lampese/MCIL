///|
async test "parse all small1 tests" {
  let base_dir = "src/frontc/testdata/small1"
  let files = @fs.readdir(base_dir, sort=true)
  let mut passed = 0
  let mut failed = 0
  let errors : Array[String] = []
  let config : PreprocessConfig = {
    compiler: "gcc",
    include_paths: [base_dir],
    defines: [("TESTDEF", "//")],
    extra_args: [],
  }
  for file in files {
    if file.has_suffix(".c") {
      let path = "\{base_dir}/\{file}"
      let source = preprocess(config, path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          errors.push("\{file}: preprocess failed - \{msg}")
          continue
        }
      }
      try {
        let lexer = Lexer::new(source, file)
        let parser = Parser::from_lexer(lexer)
        let _ = parser.parse_file()
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          errors.push("\{file}: parse failed - \{msg}")
        }
      }
    }
  }
  println("small1: \{passed} passed, \{failed} failed")
  for err in errors {
    println("  - \{err}")
  }
}

///|
async test "parse all small2 tests" {
  let base_dir = "src/frontc/testdata/small2"
  let files = @fs.readdir(base_dir, sort=true)
  let mut passed = 0
  let mut failed = 0
  let errors : Array[String] = []
  let config : PreprocessConfig = {
    compiler: "gcc",
    include_paths: [base_dir, "src/frontc/testdata/small1"],
    defines: [("TESTDEF", "//")],
    extra_args: [],
  }
  for file in files {
    if file.has_suffix(".c") {
      let path = "\{base_dir}/\{file}"
      let source = preprocess(config, path) catch {
        PreprocessError(msg) => {
          failed = failed + 1
          errors.push("\{file}: preprocess failed - \{msg}")
          continue
        }
      }
      try {
        let lexer = Lexer::new(source, file)
        let parser = Parser::from_lexer(lexer)
        let _ = parser.parse_file()
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          errors.push("\{file}: parse failed - \{msg}")
        }
      }
    }
  }
  println("small2: \{passed} passed, \{failed} failed")
  for err in errors {
    println("  - \{err}")
  }
}

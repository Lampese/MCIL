///|
async test "convert small1 to CIL" {
  let base_dir = "src/frontc/testdata/small1"
  let output_dir = "src/frontc/testdata/small1/cil_output"
  if not(@fs.exists(output_dir)) {
    @fs.mkdir(output_dir, permission=0o755)
  }
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
        let cabs = parse_c_source(source, file)
        let cil = conv_file(cabs)
        let output = @cil.print_file(cil)
        let out_file = "\{output_dir}/\{file}.cil"
        @fs.write_file(
          out_file,
          Bytes::from_iter(output.iter().map(fn(c) { c.to_int().to_byte() })),
          create=0o644,
        )
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          errors.push("\{file}: parse failed - \{msg}")
        }
        ConversionError(msg) => {
          failed = failed + 1
          errors.push("\{file}: conversion failed - \{msg}")
        }
        e => {
          failed = failed + 1
          errors.push("\{file}: error - \{e}")
        }
      }
    }
  }
  println("small1 CIL conversion: \{passed} passed, \{failed} failed")
  for err in errors {
    println("  - \{err}")
  }
}

///|
async test "convert small2 to CIL" {
  let base_dir = "src/frontc/testdata/small2"
  let output_dir = "src/frontc/testdata/small2/cil_output"
  if not(@fs.exists(output_dir)) {
    @fs.mkdir(output_dir, permission=0o755)
  }
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
        let cabs = parse_c_source(source, file)
        let cil = conv_file(cabs)
        let output = @cil.print_file(cil)
        let out_file = "\{output_dir}/\{file}.cil"
        @fs.write_file(
          out_file,
          Bytes::from_iter(output.iter().map(fn(c) { c.to_int().to_byte() })),
          create=0o644,
        )
        passed = passed + 1
      } catch {
        ParseError(msg) => {
          failed = failed + 1
          errors.push("\{file}: parse failed - \{msg}")
        }
        ConversionError(msg) => {
          failed = failed + 1
          errors.push("\{file}: conversion failed - \{msg}")
        }
        e => {
          failed = failed + 1
          errors.push("\{file}: error - \{e}")
        }
      }
    }
  }
  println("small2 CIL conversion: \{passed} passed, \{failed} failed")
  for err in errors {
    println("  - \{err}")
  }
}

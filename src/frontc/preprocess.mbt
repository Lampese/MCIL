///|
pub struct PreprocessConfig {
  compiler : String
  include_paths : Array[String]
  defines : Array[(String, String)]
  extra_args : Array[String]
}

///|
pub fn PreprocessConfig::default() -> PreprocessConfig {
  { compiler: "gcc", include_paths: [], defines: [], extra_args: [] }
}

///|
pub fn PreprocessConfig::build_args(
  self : PreprocessConfig,
  input_file : String,
) -> Array[String] {
  let args : Array[String] = []
  args.push("-E")
  for path in self.include_paths {
    args.push("-I")
    args.push(path)
  }
  for pair in self.defines {
    let (name, value) = pair
    if value.is_empty() {
      args.push("-D\{name}")
    } else {
      args.push("-D\{name}=\{value}")
    }
  }
  for arg in self.extra_args {
    args.push(arg)
  }
  args.push(input_file)
  args
}

///|
pub suberror PreprocessError String

///|
pub async fn preprocess(
  config : PreprocessConfig,
  input_file : String,
) -> String raise PreprocessError {
  let args = config.build_args(input_file)
  let result = @process.collect_output(config.compiler, args) catch {
    e => raise PreprocessError("Failed to run preprocessor: \{e}")
  }
  let (exit_code, stdout, stderr) = result
  if exit_code == 0 {
    stdout.text() catch {
      _ => raise PreprocessError("Failed to decode stdout as text")
    }
  } else {
    let err_msg = stderr.text() catch { _ => "<failed to decode stderr>" }
    raise PreprocessError("Preprocess failed (exit \{exit_code}): \{err_msg}")
  }
}

///|
pub async fn preprocess_file(
  input_file : String,
) -> String raise PreprocessError {
  let config = PreprocessConfig::default()
  preprocess(config, input_file)
}

///|
pub async fn preprocess_and_parse(
  config : PreprocessConfig,
  input_file : String,
) -> @cil.File raise PreprocessError {
  let preprocessed = preprocess(config, input_file)
  parse_and_convert(preprocessed, input_file) catch {
    ConversionError(msg) => raise PreprocessError("Conversion error: \{msg}")
  }
}

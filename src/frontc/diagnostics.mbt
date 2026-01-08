///|
pub struct DiagnosticResult {
  has_error : Bool
  output : String
}

///|
pub fn ok_diag() -> DiagnosticResult {
  { has_error: false, output: "" }
}

///|
pub fn err_diag(msg : String) -> DiagnosticResult {
  { has_error: true, output: msg }
}

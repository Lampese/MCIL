///|
pub fn escape_wchar_char(c : Char) -> String {
  let code = c.to_int()
  match c {
    '\u{07}' => "\\a"
    '\u{08}' => "\\b"
    '\t' => "\\t"
    '\n' => "\\n"
    '\u{0B}' => "\\v"
    '\u{0C}' => "\\f"
    '\r' => "\\r"
    '"' => "\\\""
    '\'' => "\\'"
    '\\' => "\\\\"
    _ =>
      if code >= 32 && code <= 126 {
        c.to_string()
      } else {
        let octal = format_octal(code)
        "\\" + octal
      }
  }
}

///|
fn format_octal(n : Int) -> String {
  let d0 = n % 8
  let n1 = n / 8
  let d1 = n1 % 8
  let n2 = n1 / 8
  let d2 = n2 % 8
  d2.to_string() + d1.to_string() + d0.to_string()
}

///|
pub fn escape_wide_string(s : String) -> String {
  let mut result = ""
  for c in s {
    result = result + escape_wchar_char(c)
  }
  result
}

///|
pub fn escape_wchar(charcode : Int64) -> String {
  let byte_limit : Int64 = 0x100L
  let octal_limit : Int64 = 0o1000L
  let uni4_limit : Int64 = 0x10000L
  let uni8_limit : Int64 = 0x100000000L
  if charcode < byte_limit {
    escape_wchar_char(Int::to_char(charcode.to_int()).unwrap())
  } else if charcode < octal_limit {
    let octal = format_octal(charcode.to_int())
    "\\" + octal
  } else if charcode < uni4_limit {
    format_unicode4(charcode.to_int())
  } else if charcode < uni8_limit {
    format_unicode8(charcode)
  } else {
    "\\?"
  }
}

///|
fn format_hex_digit(n : Int) -> String {
  if n < 10 {
    n.to_string()
  } else {
    match n {
      10 => "a"
      11 => "b"
      12 => "c"
      13 => "d"
      14 => "e"
      15 => "f"
      _ => "?"
    }
  }
}

///|
fn format_unicode4(n : Int) -> String {
  let d0 = format_hex_digit(n % 16)
  let d1 = format_hex_digit(n / 16 % 16)
  let d2 = format_hex_digit(n / 256 % 16)
  let d3 = format_hex_digit(n / 4096 % 16)
  "\\u" + d3 + d2 + d1 + d0
}

///|
fn format_unicode8(n : Int64) -> String {
  let mut result = "\\U"
  let mut value = n
  let digits : Array[String] = []
  let mut count = 0
  while count < 8 {
    digits.push(format_hex_digit((value % 16L).to_int()))
    value = value / 16L
    count = count + 1
  }
  let mut i = 7
  while i >= 0 {
    result = result + digits[i]
    i = i - 1
  }
  result
}

///|
pub fn escape_wstring(str : Array[Int64]) -> String {
  let mut result = ""
  for charcode in str {
    result = result + escape_wchar(charcode)
  }
  result
}

///|
pub fn unescape_string(s : String) -> String {
  let mut result = ""
  let mut i = 0
  while i < s.length() {
    if s[i] == '\\' && i + 1 < s.length() {
      match s[i + 1] {
        'a' => {
          result = result + "\u{07}"
          i = i + 2
        }
        'b' => {
          result = result + "\u{08}"
          i = i + 2
        }
        't' => {
          result = result + "\t"
          i = i + 2
        }
        'n' => {
          result = result + "\n"
          i = i + 2
        }
        'v' => {
          result = result + "\u{0B}"
          i = i + 2
        }
        'f' => {
          result = result + "\u{0C}"
          i = i + 2
        }
        'r' => {
          result = result + "\r"
          i = i + 2
        }
        '"' => {
          result = result + "\""
          i = i + 2
        }
        '\'' => {
          result = result + "'"
          i = i + 2
        }
        '\\' => {
          result = result + "\\"
          i = i + 2
        }
        '0' => {
          let mut value = 0
          let mut j = i + 1
          while j < s.length() && j < i + 4 && s[j] >= '0' && s[j] <= '7' {
            value = value * 8 + (s[j].to_int() - '0'.to_int())
            j = j + 1
          }
          result = result + Int::to_char(value).unwrap().to_string()
          i = j
        }
        'x' => {
          let mut value = 0
          let mut j = i + 2
          while j < s.length() &&
                (
                  (s[j] >= '0' && s[j] <= '9') ||
                  (s[j] >= 'a' && s[j] <= 'f') ||
                  (s[j] >= 'A' && s[j] <= 'F')
                ) {
            let digit = if s[j] >= '0' && s[j] <= '9' {
              s[j].to_int() - '0'.to_int()
            } else if s[j] >= 'a' && s[j] <= 'f' {
              s[j].to_int() - 'a'.to_int() + 10
            } else {
              s[j].to_int() - 'A'.to_int() + 10
            }
            value = value * 16 + digit
            j = j + 1
          }
          result = result + Int::to_char(value).unwrap().to_string()
          i = j
        }
        _ => {
          result = result + s[i + 1].to_string()
          i = i + 2
        }
      }
    } else {
      result = result + s[i].to_string()
      i = i + 1
    }
  }
  result
}

// Port of the number formatters in vega-format 1.x (BSD-3-Clause), built on
// the d3-format port: `formatFloat` and `formatSpan`.
// https://github.com/vega/vega/blob/v5.33.1/packages/vega-format/src/number.js

///|
fn rightmost_digit(s : String, dec : Int32) -> Int32? {
  let cs = s.to_array()
  match s.rev_find("e") {
    Some(i) if i > 0 => return Some(i)
    _ => ()
  }
  let mut i = cs.length() - 1
  while i > dec {
    if is_ascii_digit(cs[i]) {
      return Some(i + 1)
    }
    i = i - 1
  }
  None
}

///|
/// vega-format's `trimZeroes`: drops trailing fractional zeros (and a bare
/// decimal point) from a formatted number.
fn trim_zeroes(f : (Double) -> String) -> (Double) -> String {
  fn(x : Double) {
    let s = f(x)
    match s.find(".") {
      None => s
      Some(dec) =>
        match rightmost_digit(s, dec) {
          None => s
          Some(end_digits) => {
            let tail = if end_digits < s.length() {
              sub(s, end_digits, s.length())
            } else {
              ""
            }
            let cs = s.to_array()
            let mut idx = end_digits - 1
            // JS: while (--idx > dec) if (str[idx] !== '0') { ++idx; break; }
            let mut result_idx = idx
            let mut broke = false
            while idx > dec {
              if cs[idx] != '0' {
                result_idx = idx + 1
                broke = true
                break
              }
              idx = idx - 1
            }
            if !broke {
              result_idx = dec
            }
            sub(s, 0, result_idx) + tail
          }
        }
    }
  }
}

///|
/// vega-format's `formatFloat(spec)`: like `format`, but when the specifier has
/// no precision, formats with 12 significant digits and trims trailing zeros.
pub fn format_float(spec : String) -> ((Double) -> String) raise FormatError {
  let s = parse_specifier(if spec == "" { "," } else { spec })
  match s.precision {
    None => {
      let p = match s.kind {
        "%" => 10
        "e" => 11
        _ => 12
      }
      let s2 = { ..s, precision: Some(p), }
      trim_zeroes(format(s2.to_spec_string()))
    }
    Some(_) => format(s.to_spec_string())
  }
}

///|
fn double_to_precision(p : Double) -> Int32 {
  @util.js_to_int32(p)
}

///|
/// vega-format's `formatSpan(start, stop, count, specifier)`: a formatter whose
/// precision follows the tick step. `specifier` defaults to ",f".
pub fn format_span(
  start : Double,
  stop : Double,
  count : Double,
  specifier? : String,
) -> ((Double) -> String) raise FormatError {
  let spec = parse_specifier(
    match specifier {
      None => ",f"
      Some(s) => s
    },
  )
  let step = @stats.tick_step(start, stop, count)
  let value = @util.js_max(start.abs(), stop.abs())
  match spec.precision {
    Some(_) => format(spec.to_spec_string())
    None =>
      match spec.kind {
        "s" => {
          let p = precision_prefix(step, value)
          let spec2 = if p.is_nan() {
            spec
          } else {
            { ..spec, precision: Some(double_to_precision(p)), }
          }
          format_prefix(spec2, value)
        }
        "" | "e" | "g" | "p" | "r" => {
          let p = precision_round(step, value)
          let spec2 = if p.is_nan() {
            spec
          } else {
            let adj = if spec.kind == "e" { 1.0 } else { 0.0 }
            { ..spec, precision: Some(double_to_precision(p - adj)), }
          }
          format(spec2.to_spec_string())
        }
        "f" | "%" => {
          let p = precision_fixed(step)
          let spec2 = if p.is_nan() {
            spec
          } else {
            let adj = if spec.kind == "%" { 2.0 } else { 0.0 }
            { ..spec, precision: Some(double_to_precision(p - adj)), }
          }
          format(spec2.to_spec_string())
        }
        _ => format(spec.to_spec_string())
      }
  }
}

// The data of the benchmarks. The generator is a Park-Miller sequence computed with integers only, and
// scripts/bench/specs.mjs implements the same algorithm, so that this library and vega-lite are given
// the very same specification (checked in bench_test.mbt by a checksum computed in JavaScript).

///|
fn next_value(state : Int64) -> Int64 {
  state * 48271L % 2147483647L
}

///|
/// 10,000 rows (a category among 20 and an integer value) averaged per category and drawn as bars.
pub fn aggregate_bar_spec(rows : Int32) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"data\":{\"values\":[")
  let mut s = 1L
  for i in 0..<rows {
    s = next_value(s)
    let category = s % 20L
    s = next_value(s)
    let value = s % 10000L
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"cat\":\"c\{category}\",\"v\":\{value}}")
  }
  buf.write_string(
    "]},\"mark\":\"bar\",\"encoding\":{\"x\":{\"field\":\"cat\",\"type\":\"nominal\"},\"y\":{\"aggregate\":\"mean\",\"field\":\"v\",\"type\":\"quantitative\"}}}",
  )
  buf.to_string()
}

///|
/// 100,000 points with integer coordinates.
pub fn scatter_spec(points : Int32) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"data\":{\"values\":[")
  let mut s = 1L
  for i in 0..<points {
    s = next_value(s)
    let x = s % 10000L
    s = next_value(s)
    let y = s % 10000L
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"x\":\{x},\"y\":\{y}}")
  }
  buf.write_string(
    "]},\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"x\",\"type\":\"quantitative\"},\"y\":{\"field\":\"y\",\"type\":\"quantitative\"}}}",
  )
  buf.to_string()
}

///|
/// 32-bit FNV-1a of the UTF-16 code units of a string (ASCII text: its bytes).
pub fn checksum(text : String) -> Int64 {
  let mut h = 2166136261L
  for c in text {
    h = ((h ^ c.to_int().to_int64()) * 16777619L) & 0xFFFFFFFFL
  }
  h
}

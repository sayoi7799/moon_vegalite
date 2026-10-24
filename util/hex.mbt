// Bit-exact Double <-> hex conversion. Fixtures encode every double as the 16 hex
// digits of its IEEE-754 bits, so comparisons never depend on number parsing.

///|
/// Parse 16 lowercase hex digits as the bit pattern of a Double.
pub fn double_from_hex(hex : String) -> Double {
  let mut bits = 0UL
  for c in hex {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    bits = bits * 16UL + d.to_uint64()
  }
  bits.reinterpret_as_double()
}

///|
/// The 16 hex digits of a Double's bit pattern; every NaN prints as 7ff8000000000000.
pub fn double_to_hex(x : Double) -> String {
  let bits = if x.is_nan() {
    0x7ff8000000000000UL
  } else {
    x.reinterpret_as_uint64()
  }
  let digits : Array[Char] = "0123456789abcdef".to_array()
  let out = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    let nibble = ((bits >> (i * 4)) & 0xfUL).to_int()
    out.write_char(digits[nibble])
  }
  out.to_string()
}

///|
/// True when both doubles have identical bits (NaNs compare equal).
pub fn same_bits(a : Double, b : Double) -> Bool {
  a.reinterpret_as_uint64() == b.reinterpret_as_uint64() ||
  (a.is_nan() && b.is_nan())
}

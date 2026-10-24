// Math.sin / Math.cos that agree bit for bit with V8 for angles that are whole
// degrees (the only angles Vega's layout feeds into them). The platform libm
// differs by an ulp for some of these values (e.g. sin(45 deg)), which would
// change pixel positions after Math.ceil in the layout, so a table generated
// from Node is used for them.

///|
let deg_to_rad : Double = 3.141592653589793 / 180.0

///|
fn deg_index(x : Double) -> Int32? {
  if x == 0.0 || x.is_nan() || x.is_inf() {
    return None
  }
  let k = js_round(x / deg_to_rad)
  if k.abs() <= 720.0 && k * deg_to_rad == x {
    Some(k.to_int() + 720)
  } else {
    None
  }
}

///|
pub fn js_cos(x : Double) -> Double {
  match deg_index(x) {
    Some(i) => cos_deg_bits[i].reinterpret_as_double()
    None => @math.cos(x)
  }
}

///|
pub fn js_sin(x : Double) -> Double {
  match deg_index(x) {
    Some(i) => sin_deg_bits[i].reinterpret_as_double()
    None => @math.sin(x)
  }
}

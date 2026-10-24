// Colour schemes by name, as vega-scale's `scheme(name)`.

///|
/// A named colour scheme: a list of colours for ordinal scales, or an
/// interpolator over [0, 1] for continuous ones.
pub enum Scheme {
  Discrete(Array[String])
  Interpolating((Double) -> String)
}

///|
/// Look up a scheme (names are case-insensitive).
pub fn scheme(name : String) -> Scheme? {
  let key = name.to_lower()
  match discrete_palette(key) {
    Some(colors) => Some(Discrete(colors))
    None =>
      match continuous_palette(key) {
        Some(colors) => Some(Interpolating(interpolate_colors(colors)))
        None => None
      }
  }
}

///|
/// The continuous interpolator of a named scheme (vega's `scheme(name)` for
/// sequential scales), when the scheme has one.
pub fn scheme_interpolator(name : String) -> ((Double) -> String)? {
  match continuous_palette(name.to_lower()) {
    Some(colors) => Some(interpolate_colors(colors))
    None => None
  }
}

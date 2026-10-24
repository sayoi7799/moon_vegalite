// A runtime scale: one of the ported scale implementations plus the
// information axes and encoders need to query it uniformly.

///|
pub(all) enum RScale {
  Cont(@scale.Continuous)
  /// a linear scale over bin boundaries (the boundaries drive axis ticks)
  Binned(@scale.Continuous, Array[Double])
  /// a time scale over epoch milliseconds (UTC)
  Time(@scale.Continuous)
  Band(@scale.Band)
}

///|
fn RScale::range_ends(self : RScale) -> (Double, Double) {
  match self {
    Cont(c) | Time(c) | Binned(c, _) =>
      (c.range[0], c.range[c.range.length() - 1])
    Band(b) => b.range
  }
}

///|
/// `scale(value)`, None for values outside a discrete domain or invalid input.
fn RScale::map(self : RScale, v : @value.Value) -> Double? {
  match self {
    Cont(c) | Time(c) | Binned(c, _) =>
      match v.coerce_number() {
        Num(x) => c.map(x)
        _ => None
      }
    Band(b) => b.map(v)
  }
}

///|
fn RScale::bandwidth(self : RScale) -> Double {
  match self {
    Cont(_) | Time(_) | Binned(_, _) => 0.0
    Band(b) => b.bandwidth
  }
}

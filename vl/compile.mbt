// The compile entry point: Vega-Lite text in, scenegraph out.

///|
pub(all) struct Compiled {
  scene : @scene.Mark
  width : Double
  height : Double
  /// layout offset of the root group inside the padded view
  origin : (Double, Double)
  padding : Double
  /// size of the whole view without padding
  view_width : Double
  view_height : Double
  background : String?
}

///|
fn spec_err(e : @spec.SpecError) -> CompileError {
  CompileError(e.message())
}

///|
fn find_channel(spec : @spec.Spec, name : String) -> @spec.ChannelDef? {
  for e in spec.encoding {
    if e.0 == name {
      return Some(e.1)
    }
  }
  None
}

///|
fn need_field(
  c : @spec.ChannelDef?,
  what : String,
) -> String raise CompileError {
  match c {
    Some({ field: Some(f), .. }) => f
    _ => raise CompileError("encoding." + what + ".field 缺失")
  }
}

///|
fn is_finite_valid(v : @value.Value) -> Bool {
  v.is_valid() && !v.to_number().is_nan() && !v.to_number().is_inf()
}

///|
/// Distinct values in ascending order (vega `sort: true` domains).
fn sorted_unique(
  rows : Array[Map[String, @value.Value]],
  field : String,
) -> Array[@value.Value] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[@value.Value] = []
  for r in rows {
    let v = @value.get_field(r, field)
    let k = @scale.value_key(v)
    if !seen.contains(k) {
      seen[k] = true
      out.push(v)
    }
  }
  @transform.stable_sort(out, fn(a, b) { @value.compare_values(a, b) })
}

// Benchmarks (run with `moon bench --release --target js|wasm-gc|native -p sayoi7799/moon_vegalite/benchmarks`)
// and the checks that the benchmarks measure what they claim to.

///|
/// The length of the SVG (a number the optimiser cannot drop); a failure aborts the benchmark.
fn render_length(spec : String) -> Int32 {
  @moon_vegalite.render_svg(spec).length() catch {
    e => abort(e.message())
  }
}

///|
fn scene_items(spec : String) -> Int32 {
  @moon_vegalite.compile(spec).scene.items.length() catch {
    e => abort(e.message())
  }
}

///|
test "the generated specifications are the ones scripts/bench/specs.mjs generates" {
  // checksums computed by the JavaScript implementation of the same generator
  assert_eq(
    @benchmarks.checksum(@benchmarks.aggregate_bar_spec(10)),
    3015400466L,
  )
  assert_eq(@benchmarks.checksum(@benchmarks.scatter_spec(10)), 3024209669L)
  assert_eq(
    @benchmarks.checksum(@benchmarks.aggregate_bar_spec(10000)),
    3195346028L,
  )
  assert_eq(@benchmarks.checksum(@benchmarks.scatter_spec(100000)), 2814876481L)
}

///|
test "the benchmark specifications render" {
  for
    spec in [
      @benchmarks.aggregate_bar_spec(1000),
      @benchmarks.scatter_spec(1000),
    ] {
    assert_true(@moon_vegalite.render_svg(spec).has_prefix("<svg "))
  }
}

///|
test "bench: 10,000 rows aggregated to a bar chart, specification text to SVG" (
  it : @bench.T,
) {
  let spec = @benchmarks.aggregate_bar_spec(10000)
  it.bench(fn() { it.keep(render_length(spec)) })
}

///|
test "bench: 10,000 rows aggregated to a bar chart, specification text to scenegraph" (
  it : @bench.T,
) {
  let spec = @benchmarks.aggregate_bar_spec(10000)
  it.bench(fn() { it.keep(scene_items(spec)) })
}

///|
test "bench: 100,000-point scatter plot, specification text to SVG" (
  it : @bench.T,
) {
  let spec = @benchmarks.scatter_spec(100000)
  it.bench(fn() { it.keep(render_length(spec)) })
}

///|
test "bench: 100,000-point scatter plot, specification text to scenegraph" (
  it : @bench.T,
) {
  let spec = @benchmarks.scatter_spec(100000)
  it.bench(fn() { it.keep(scene_items(spec)) })
}

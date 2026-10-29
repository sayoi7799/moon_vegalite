// MoonFrame → moon_vegalite: a CSV file becomes SVG charts without leaving
// MoonBit and without opening the Vega editor.
//
//   read_csv → group_by / agg (MoonFrame)
//            → format_vega_lite (MoonFrame: DataFrame + ChartSpec → Vega-Lite JSON)
//            → render_svg (moon_vegalite: Vega-Lite JSON → SVG)
//
// Run from this directory:  moon run cmd

///|
/// Write the Vega-Lite specification MoonFrame generates for `df` next to the
/// SVG this library draws from it.
fn render_chart(
  name : String,
  df : @moonframe.DataFrame,
  chart : @moonframe.ChartSpec,
) -> Unit raise Error {
  let spec = @moonframe.format_vega_lite(df, chart)
  @mfio.write_text("out/" + name + ".vl.json", spec)
  let svg = @moon_vegalite.render_svg(spec)
  @mfio.write_text("out/" + name + ".svg", svg)
  println("out/" + name + ".svg  (" + svg.length().to_string() + " characters)")
}

///|
fn run() -> Unit raise Error {
  let sales = @moonframe.read_csv("data/sales.csv")
  println(
    "read " +
    sales.nrows().to_string() +
    " rows, " +
    sales.ncols().to_string() +
    " columns from data/sales.csv",
  )
  // revenue per region, the largest first
  let by_region = sales
    .group_by([@moonframe.col("region")])
    .agg([@moonframe.col("revenue").sum().with_alias("revenue")])
    .sort([(@moonframe.col("revenue"), true, true)])
  render_chart(
    "revenue_by_region",
    by_region,
    @moonframe.ChartSpec::bar("region", "revenue", title="Revenue by region"),
  )
  // revenue per month, a time series
  let by_month = sales
    .group_by([@moonframe.col("month")])
    .agg([@moonframe.col("revenue").sum().with_alias("revenue")])
    .sort([(@moonframe.col("month"), false, true)])
  render_chart(
    "revenue_by_month",
    by_month,
    @moonframe.ChartSpec::line("month", "revenue", title="Revenue by month"),
  )
  // units against price, coloured by region
  render_chart(
    "units_vs_price",
    sales,
    @moonframe.ChartSpec::point(
      "price",
      "units",
      color="region",
      title="Units against price",
    ),
  )
}

///|
fn main {
  run() catch {
    e => println("error: " + e.to_string())
  }
}

// GENERATED FILE. DO NOT EDIT.
// Regenerate with: cd scripts && npm ci && npm run fixtures

///|
/// A hand-drawn rendering and what vega-lite 5.23.0 + vega 5.33.1 + rough.js 4.6.6 give for it.
pub(all) struct SketchCase {
  name : String
  spec : String
  seed : Int32
  roughness : Double
  bowing : Double
  fill_style : String
  hachure_gap : Double?
  fill_weight : Double?
  fixed_decimals : Int32?
  svg : String
}

///|
pub fn cases() -> Array[SketchCase] {
  [
    {
      name: "bar",
      spec: spec_0_0,
      seed: 7,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_0_0 + svg_0_1,
    },
    {
      name: "bar_cross_hatch_rough",
      spec: spec_1_0,
      seed: 3,
      roughness: 2.0,
      bowing: 1.0,
      fill_style: "cross-hatch",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_1_0 + svg_1_1 + svg_1_2 + svg_1_3,
    },
    {
      name: "bar_zigzag_seed_1",
      spec: spec_2_0,
      seed: 1,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "zigzag",
      hachure_gap: Some(6.0),
      fill_weight: Some(2.0),
      fixed_decimals: None,
      svg: svg_2_0 + svg_2_1 + svg_2_2,
    },
    {
      name: "bar_two_decimals",
      spec: spec_3_0,
      seed: 7,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: Some(2),
      svg: svg_3_0,
    },
    {
      name: "point_ordinal_color_one_decimal",
      spec: spec_4_0,
      seed: 4,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: Some(1),
      svg: svg_4_0,
    },
    {
      name: "layer_bar_line_solid",
      spec: spec_5_0,
      seed: 9,
      roughness: 1.0,
      bowing: 0.5,
      fill_style: "solid",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_5_0,
    },
    {
      name: "layer_bar_annotations",
      spec: spec_6_0,
      seed: 3,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_6_0 + svg_6_1 + svg_6_2,
    },
    {
      name: "point_ordinal_color",
      spec: spec_7_0,
      seed: 5,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_7_0,
    },
    {
      name: "custom_channel_shape_size",
      spec: spec_8_0,
      seed: 11,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_8_0 + svg_8_1,
    },
    {
      name: "custom_series_area",
      spec: spec_9_0,
      seed: 5,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_9_0 + svg_9_1,
    },
    {
      name: "custom_layer_independent_y",
      spec: spec_10_0,
      seed: 2,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "dashed",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_10_0,
    },
    {
      name: "moonframe_bar_stacked",
      spec: spec_11_0,
      seed: 12,
      roughness: 1.0,
      bowing: 1.0,
      fill_style: "hachure",
      hachure_gap: None,
      fill_weight: None,
      fixed_decimals: None,
      svg: svg_11_0 + svg_11_1,
    },
  ]
}

// GENERATED FILE. DO NOT EDIT.
// Regenerate with: cd scripts && npm ci && npm run fixtures

///|
/// (name, Vega-Lite spec, official scenegraph export, official SVG)
pub fn cases() -> Array[(String, String, String, String)] {
  [
    ("area", spec_0_0 + spec_0_1 + spec_0_2, scene_0_0, svg_0_0),
    ("area_vertical", spec_1_0, scene_1_0, svg_1_0),
    ("bar", spec_2_0, scene_2_0, svg_2_0),
    ("bar_aggregate", spec_3_0, scene_3_0, svg_3_0),
    ("bar_aggregate_count", spec_4_0, scene_4_0, svg_4_0),
    ("bar_aggregate_format", spec_5_0, scene_5_0, svg_5_0),
    ("bar_aggregate_transform", spec_6_0, scene_6_0, svg_6_0),
    ("bar_aggregate_vertical", spec_7_0, scene_7_0, svg_7_0),
    ("bar_array_aggregate", spec_8_0, scene_8_0, svg_8_0),
    ("bar_config_no_zero", spec_9_0, scene_9_0, svg_9_0),
    ("bar_distinct", spec_10_0, scene_10_0, svg_10_0),
    ("bar_filter_calc", spec_11_0, scene_11_0, svg_11_0),
    ("bar_month", spec_12_0 + spec_12_1, scene_12_0, svg_12_0),
    ("bar_month_temporal", spec_13_0 + spec_13_1, scene_13_0, svg_13_0),
    ("bar_negative", spec_14_0, scene_14_0, svg_14_0),
    ("bar_size_default", spec_15_0, scene_15_0, svg_15_0),
    ("bar_size_step_small", spec_16_0, scene_16_0, svg_16_0),
    ("bar_swap_axes", spec_17_0, scene_17_0, svg_17_0),
    ("bar_swap_custom", spec_18_0, scene_18_0, svg_18_0),
    ("bar_yearmonth", spec_19_0 + spec_19_1, scene_19_0, svg_19_0),
    ("bar_yearmonth_custom_format", spec_20_0 + spec_20_1, scene_20_0, svg_20_0),
    ("circle", spec_21_0, scene_21_0 + scene_21_1, svg_21_0 + svg_21_1),
    ("histogram", spec_22_0 + spec_22_1, scene_22_0, svg_22_0),
    ("histogram_bin_change", spec_23_0 + spec_23_1, scene_23_0, svg_23_0),
    ("line", spec_24_0, scene_24_0, svg_24_0),
    ("line_calculate", spec_25_0 + spec_25_1, scene_25_0, svg_25_0),
    ("line_mean_month", spec_26_0 + spec_26_1, scene_26_0, svg_26_0),
    ("line_mean_year", spec_27_0 + spec_27_1, scene_27_0, svg_27_0),
    ("line_monotone", spec_28_0, scene_28_0, svg_28_0),
    ("line_month", spec_29_0 + spec_29_1, scene_29_0, svg_29_0),
    ("line_step", spec_30_0, scene_30_0, svg_30_0),
    (
      "point_1d",
      spec_31_0 + spec_31_1,
      scene_31_0 +
      scene_31_1 +
      scene_31_2 +
      scene_31_3 +
      scene_31_4 +
      scene_31_5 +
      scene_31_6 +
      scene_31_7 +
      scene_31_8 +
      scene_31_9 +
      scene_31_10 +
      scene_31_11 +
      scene_31_12 +
      scene_31_13,
      svg_31_0 +
      svg_31_1 +
      svg_31_2 +
      svg_31_3 +
      svg_31_4 +
      svg_31_5 +
      svg_31_6 +
      svg_31_7 +
      svg_31_8 +
      svg_31_9,
    ),
    ("point_1d_array", spec_32_0, scene_32_0, svg_32_0),
    ("point_2d", spec_33_0, scene_33_0 + scene_33_1, svg_33_0 + svg_33_1),
    ("point_2d_array", spec_34_0, scene_34_0, svg_34_0),
    (
      "point_color",
      spec_35_0,
      scene_35_0 + scene_35_1 + scene_35_2,
      svg_35_0 + svg_35_1,
    ),
    ("point_filled", spec_36_0, scene_36_0 + scene_36_1, svg_36_0 + svg_36_1),
    ("rule_extent", spec_37_0, scene_37_0, svg_37_0),
    ("square", spec_38_0, scene_38_0 + scene_38_1, svg_38_0 + svg_38_1),
    ("stacked_bar_count", spec_39_0 + spec_39_1, scene_39_0, svg_39_0),
    ("stacked_bar_unaggregate", spec_40_0, scene_40_0, svg_40_0),
    ("stacked_bar_v", spec_41_0, scene_41_0, svg_41_0),
    ("test_field_with_spaces", spec_42_0, scene_42_0, svg_42_0),
    ("test_subobject_missing", spec_43_0, scene_43_0, svg_43_0),
    ("text_format", spec_44_0, scene_44_0, svg_44_0),
    (
      "text_scatterplot_colored",
      spec_45_0,
      scene_45_0 + scene_45_1,
      svg_45_0 + svg_45_1,
    ),
    (
      "tick_dot",
      spec_46_0,
      scene_46_0 + scene_46_1 + scene_46_2 + scene_46_3 + scene_46_4,
      svg_46_0 + svg_46_1,
    ),
    ("tick_strip", spec_47_0, scene_47_0 + scene_47_1, svg_47_0),
    ("tick_strip_1D_with_height", spec_48_0, scene_48_0 + scene_48_1, svg_48_0),
    ("time_parse_local", spec_49_0, scene_49_0, svg_49_0),
    ("custom_bar_basic", spec_50_0, scene_50_0, svg_50_0),
    ("custom_edge_all_null", spec_51_0, scene_51_0, svg_51_0),
    ("custom_edge_empty_data", spec_52_0, scene_52_0, svg_52_0),
    ("custom_edge_log_out_of_range", spec_53_0, scene_53_0, svg_53_0),
    ("custom_edge_single_value", spec_54_0, scene_54_0, svg_54_0),
    ("moonframe_area", spec_55_0, scene_55_0, svg_55_0),
    ("moonframe_bar", spec_56_0, scene_56_0, svg_56_0),
    ("moonframe_bar_null", spec_57_0, scene_57_0, svg_57_0),
    ("moonframe_bar_stacked", spec_58_0, scene_58_0, svg_58_0),
    ("moonframe_bar_titled", spec_59_0, scene_59_0, svg_59_0),
    ("moonframe_line", spec_60_0, scene_60_0, svg_60_0),
    ("moonframe_point_color", spec_61_0, scene_61_0, svg_61_0),
  ]
}

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
    (
      "point_bubble",
      spec_50_0,
      scene_50_0 + scene_50_1 + scene_50_2,
      svg_50_0 + svg_50_1,
    ),
    (
      "point_color_with_shape",
      spec_51_0,
      scene_51_0 + scene_51_1,
      svg_51_0 + svg_51_1,
    ),
    (
      "point_color_shape_constant",
      spec_52_0,
      scene_52_0 + scene_52_1,
      svg_52_0 + svg_52_1,
    ),
    ("bar_aggregate_sort_by_encoding", spec_53_0, scene_53_0, svg_53_0),
    ("bar_sort_by_count", spec_54_0, scene_54_0, svg_54_0),
    ("bar_custom_sort_full", spec_55_0, scene_55_0, svg_55_0),
    ("bar_custom_sort_partial", spec_56_0, scene_56_0, svg_56_0),
    ("bar_aggregate_sort_mean", spec_57_0, scene_57_0, svg_57_0),
    ("line_sort_axis", spec_58_0, scene_58_0, svg_58_0),
    (
      "point_color_quantitative",
      spec_59_0,
      scene_59_0 + scene_59_1 + scene_59_2,
      svg_59_0 + svg_59_1,
    ),
    ("layer_bar_line", spec_60_0, scene_60_0, svg_60_0),
    ("custom_bar_basic", spec_61_0, scene_61_0, svg_61_0),
    ("custom_channel_constants", spec_62_0, scene_62_0, svg_62_0),
    ("custom_channel_opacity", spec_63_0, scene_63_0, svg_63_0),
    ("custom_channel_shape_size", spec_64_0, scene_64_0, svg_64_0),
    ("custom_channel_size_color", spec_65_0, scene_65_0, svg_65_0),
    ("custom_channel_two_legends", spec_66_0, scene_66_0, svg_66_0),
    ("custom_color_quantitative_bar", spec_67_0, scene_67_0, svg_67_0),
    ("custom_color_quantitative_size", spec_68_0, scene_68_0, svg_68_0),
    ("custom_edge_all_null", spec_69_0, scene_69_0, svg_69_0),
    ("custom_edge_empty_data", spec_70_0, scene_70_0, svg_70_0),
    ("custom_edge_log_out_of_range", spec_71_0, scene_71_0, svg_71_0),
    ("custom_edge_single_value", spec_72_0, scene_72_0, svg_72_0),
    ("custom_layer_bar_color_point", spec_73_0, scene_73_0, svg_73_0),
    ("custom_layer_independent_color", spec_74_0, scene_74_0, svg_74_0),
    ("custom_layer_independent_xy", spec_75_0, scene_75_0, svg_75_0),
    ("custom_layer_independent_y", spec_76_0, scene_76_0, svg_76_0),
    ("custom_layer_inherit_encoding", spec_77_0, scene_77_0, svg_77_0),
    ("custom_layer_nested", spec_78_0, scene_78_0, svg_78_0),
    ("custom_layer_own_data", spec_79_0, scene_79_0, svg_79_0),
    ("custom_layer_shared_color", spec_80_0, scene_80_0, svg_80_0),
    ("custom_layer_three_y", spec_81_0, scene_81_0, svg_81_0),
    ("custom_layer_title_size", spec_82_0, scene_82_0, svg_82_0),
    ("custom_layer_transform_scope", spec_83_0, scene_83_0, svg_83_0),
    ("custom_layer_two_y_fields", spec_84_0, scene_84_0, svg_84_0),
    ("custom_stack_center", spec_85_0, scene_85_0, svg_85_0),
    ("custom_stack_none", spec_86_0, scene_86_0, svg_86_0),
    ("custom_stack_normalize", spec_87_0, scene_87_0, svg_87_0),
    ("moonframe_area", spec_88_0, scene_88_0, svg_88_0),
    ("moonframe_bar", spec_89_0, scene_89_0, svg_89_0),
    ("moonframe_bar_null", spec_90_0, scene_90_0, svg_90_0),
    ("moonframe_bar_stacked", spec_91_0, scene_91_0, svg_91_0),
    ("moonframe_bar_titled", spec_92_0, scene_92_0, svg_92_0),
    ("moonframe_line", spec_93_0, scene_93_0, svg_93_0),
    ("moonframe_point_color", spec_94_0, scene_94_0, svg_94_0),
  ]
}

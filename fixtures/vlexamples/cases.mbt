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
    ("bar_aggregate_sort_by_encoding", spec_6_0, scene_6_0, svg_6_0),
    ("bar_aggregate_sort_mean", spec_7_0, scene_7_0, svg_7_0),
    ("bar_aggregate_transform", spec_8_0, scene_8_0, svg_8_0),
    ("bar_aggregate_vertical", spec_9_0, scene_9_0, svg_9_0),
    ("bar_array_aggregate", spec_10_0, scene_10_0, svg_10_0),
    ("bar_config_no_zero", spec_11_0, scene_11_0, svg_11_0),
    ("bar_custom_sort_full", spec_12_0, scene_12_0, svg_12_0),
    ("bar_custom_sort_partial", spec_13_0, scene_13_0, svg_13_0),
    ("bar_distinct", spec_14_0, scene_14_0, svg_14_0),
    ("bar_filter_calc", spec_15_0, scene_15_0, svg_15_0),
    ("bar_month", spec_16_0 + spec_16_1, scene_16_0, svg_16_0),
    ("bar_month_temporal", spec_17_0 + spec_17_1, scene_17_0, svg_17_0),
    ("bar_negative", spec_18_0, scene_18_0, svg_18_0),
    ("bar_size_default", spec_19_0, scene_19_0, svg_19_0),
    ("bar_size_step_small", spec_20_0, scene_20_0, svg_20_0),
    ("bar_sort_by_count", spec_21_0, scene_21_0, svg_21_0),
    ("bar_swap_axes", spec_22_0, scene_22_0, svg_22_0),
    ("bar_swap_custom", spec_23_0, scene_23_0, svg_23_0),
    ("bar_yearmonth", spec_24_0 + spec_24_1, scene_24_0, svg_24_0),
    ("bar_yearmonth_custom_format", spec_25_0 + spec_25_1, scene_25_0, svg_25_0),
    ("circle", spec_26_0, scene_26_0 + scene_26_1, svg_26_0 + svg_26_1),
    ("histogram", spec_27_0 + spec_27_1, scene_27_0, svg_27_0),
    ("histogram_bin_change", spec_28_0 + spec_28_1, scene_28_0, svg_28_0),
    ("layer_bar_annotations", spec_29_0, scene_29_0, svg_29_0),
    ("layer_bar_labels", spec_30_0, scene_30_0, svg_30_0),
    ("layer_bar_line", spec_31_0, scene_31_0, svg_31_0),
    ("layer_bar_line_union", spec_32_0, scene_32_0, svg_32_0),
    ("layer_bar_month", spec_33_0 + spec_33_1, scene_33_0, svg_33_0),
    ("layer_histogram", spec_34_0 + spec_34_1, scene_34_0, svg_34_0),
    ("layer_histogram_global_mean", spec_35_0 + spec_35_1, scene_35_0, svg_35_0),
    ("layer_line_color_rule", spec_36_0, scene_36_0 + scene_36_1, svg_36_0),
    ("layer_line_datum_rule", spec_37_0, scene_37_0 + scene_37_1, svg_37_0),
    ("layer_line_mean_point_raw", spec_38_0, scene_38_0, svg_38_0),
    ("layer_precipitation_mean", spec_39_0 + spec_39_1, scene_39_0, svg_39_0),
    (
      "layer_rect_extent",
      spec_40_0,
      scene_40_0 + scene_40_1 + scene_40_2,
      svg_40_0 + svg_40_1,
    ),
    ("layer_single_color", spec_41_0, scene_41_0 + scene_41_1, svg_41_0),
    ("line", spec_42_0, scene_42_0, svg_42_0),
    ("line_calculate", spec_43_0 + spec_43_1, scene_43_0, svg_43_0),
    ("line_color", spec_44_0, scene_44_0 + scene_44_1, svg_44_0),
    ("line_mean_month", spec_45_0 + spec_45_1, scene_45_0, svg_45_0),
    ("line_mean_year", spec_46_0 + spec_46_1, scene_46_0, svg_46_0),
    ("line_monotone", spec_47_0, scene_47_0, svg_47_0),
    ("line_month", spec_48_0 + spec_48_1, scene_48_0, svg_48_0),
    ("line_sort_axis", spec_49_0, scene_49_0, svg_49_0),
    ("line_step", spec_50_0, scene_50_0, svg_50_0),
    (
      "point_1d",
      spec_51_0 + spec_51_1,
      scene_51_0 +
      scene_51_1 +
      scene_51_2 +
      scene_51_3 +
      scene_51_4 +
      scene_51_5 +
      scene_51_6 +
      scene_51_7 +
      scene_51_8 +
      scene_51_9 +
      scene_51_10 +
      scene_51_11 +
      scene_51_12 +
      scene_51_13,
      svg_51_0 +
      svg_51_1 +
      svg_51_2 +
      svg_51_3 +
      svg_51_4 +
      svg_51_5 +
      svg_51_6 +
      svg_51_7 +
      svg_51_8 +
      svg_51_9,
    ),
    ("point_1d_array", spec_52_0, scene_52_0, svg_52_0),
    ("point_2d", spec_53_0, scene_53_0 + scene_53_1, svg_53_0 + svg_53_1),
    ("point_2d_array", spec_54_0, scene_54_0, svg_54_0),
    (
      "point_bubble",
      spec_55_0,
      scene_55_0 + scene_55_1 + scene_55_2,
      svg_55_0 + svg_55_1,
    ),
    (
      "point_color",
      spec_56_0,
      scene_56_0 + scene_56_1 + scene_56_2,
      svg_56_0 + svg_56_1,
    ),
    (
      "point_color_quantitative",
      spec_57_0,
      scene_57_0 + scene_57_1 + scene_57_2,
      svg_57_0 + svg_57_1,
    ),
    (
      "point_color_shape_constant",
      spec_58_0,
      scene_58_0 + scene_58_1,
      svg_58_0 + svg_58_1,
    ),
    (
      "point_color_with_shape",
      spec_59_0,
      scene_59_0 + scene_59_1,
      svg_59_0 + svg_59_1,
    ),
    ("point_filled", spec_60_0, scene_60_0 + scene_60_1, svg_60_0 + svg_60_1),
    ("point_ordinal_color", spec_61_0, scene_61_0, svg_61_0),
    ("rule_extent", spec_62_0, scene_62_0, svg_62_0),
    ("square", spec_63_0, scene_63_0 + scene_63_1, svg_63_0 + svg_63_1),
    ("stacked_area_ordinal", spec_64_0, scene_64_0, svg_64_0),
    ("stacked_bar_count", spec_65_0 + spec_65_1, scene_65_0, svg_65_0),
    ("stacked_bar_unaggregate", spec_66_0, scene_66_0, svg_66_0),
    ("stacked_bar_v", spec_67_0, scene_67_0, svg_67_0),
    ("test_field_with_spaces", spec_68_0, scene_68_0, svg_68_0),
    ("test_subobject_missing", spec_69_0, scene_69_0, svg_69_0),
    ("text_format", spec_70_0, scene_70_0, svg_70_0),
    (
      "text_scatterplot_colored",
      spec_71_0,
      scene_71_0 + scene_71_1,
      svg_71_0 + svg_71_1,
    ),
    (
      "tick_dot",
      spec_72_0,
      scene_72_0 + scene_72_1 + scene_72_2 + scene_72_3 + scene_72_4,
      svg_72_0 + svg_72_1,
    ),
    ("tick_strip", spec_73_0, scene_73_0 + scene_73_1, svg_73_0),
    ("tick_strip_1D_with_height", spec_74_0, scene_74_0 + scene_74_1, svg_74_0),
    ("time_parse_local", spec_75_0, scene_75_0, svg_75_0),
    ("custom_bar_basic", spec_76_0, scene_76_0, svg_76_0),
    ("custom_channel_color_ordinal", spec_77_0, scene_77_0, svg_77_0),
    ("custom_channel_constants", spec_78_0, scene_78_0, svg_78_0),
    ("custom_channel_opacity", spec_79_0, scene_79_0, svg_79_0),
    ("custom_channel_shape_size", spec_80_0, scene_80_0, svg_80_0),
    ("custom_channel_size_color", spec_81_0, scene_81_0, svg_81_0),
    ("custom_channel_two_legends", spec_82_0, scene_82_0, svg_82_0),
    ("custom_color_quantitative_bar", spec_83_0, scene_83_0, svg_83_0),
    ("custom_color_quantitative_size", spec_84_0, scene_84_0, svg_84_0),
    ("custom_edge_all_null", spec_85_0, scene_85_0, svg_85_0),
    ("custom_edge_empty_data", spec_86_0, scene_86_0, svg_86_0),
    ("custom_edge_log_out_of_range", spec_87_0, scene_87_0, svg_87_0),
    ("custom_edge_single_value", spec_88_0, scene_88_0, svg_88_0),
    ("custom_layer_bar_color_point", spec_89_0, scene_89_0, svg_89_0),
    ("custom_layer_bin_horizontal", spec_90_0, scene_90_0, svg_90_0),
    ("custom_layer_bin_shared", spec_91_0, scene_91_0, svg_91_0),
    ("custom_layer_datum_rules", spec_92_0, scene_92_0, svg_92_0),
    ("custom_layer_independent_color", spec_93_0, scene_93_0, svg_93_0),
    ("custom_layer_independent_xy", spec_94_0, scene_94_0, svg_94_0),
    ("custom_layer_independent_y", spec_95_0, scene_95_0, svg_95_0),
    ("custom_layer_inherit_encoding", spec_96_0, scene_96_0, svg_96_0),
    ("custom_layer_nested", spec_97_0, scene_97_0, svg_97_0),
    ("custom_layer_own_data", spec_98_0, scene_98_0, svg_98_0),
    ("custom_layer_ranged", spec_99_0, scene_99_0, svg_99_0),
    ("custom_layer_rule_x", spec_100_0, scene_100_0, svg_100_0),
    ("custom_layer_series_and_points", spec_101_0, scene_101_0, svg_101_0),
    ("custom_layer_shared_color", spec_102_0, scene_102_0, svg_102_0),
    ("custom_layer_three_y", spec_103_0, scene_103_0, svg_103_0),
    ("custom_layer_title_size", spec_104_0, scene_104_0, svg_104_0),
    ("custom_layer_transform_scope", spec_105_0, scene_105_0, svg_105_0),
    ("custom_layer_two_y_fields", spec_106_0, scene_106_0, svg_106_0),
    ("custom_series_area", spec_107_0, scene_107_0, svg_107_0),
    ("custom_series_line_opacity", spec_108_0, scene_108_0, svg_108_0),
    ("custom_stack_area_impute", spec_109_0, scene_109_0, svg_109_0),
    ("custom_stack_center", spec_110_0, scene_110_0, svg_110_0),
    ("custom_stack_none", spec_111_0, scene_111_0, svg_111_0),
    ("custom_stack_normalize", spec_112_0, scene_112_0, svg_112_0),
    ("custom_text_props", spec_113_0, scene_113_0, svg_113_0),
    ("moonframe_area", spec_114_0, scene_114_0, svg_114_0),
    ("moonframe_bar", spec_115_0, scene_115_0, svg_115_0),
    ("moonframe_bar_null", spec_116_0, scene_116_0, svg_116_0),
    ("moonframe_bar_stacked", spec_117_0, scene_117_0, svg_117_0),
    ("moonframe_bar_titled", spec_118_0, scene_118_0, svg_118_0),
    ("moonframe_line", spec_119_0, scene_119_0, svg_119_0),
    ("moonframe_point_color", spec_120_0, scene_120_0, svg_120_0),
  ]
}

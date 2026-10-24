// GENERATED FILE. DO NOT EDIT.
// Regenerate with: cd scripts && npm ci && npm run fixtures
// Colour tables of vega-scale 7.4.3 (BSD-3-Clause) and d3-scale-chromatic (ISC/Apache-2.0), see README.

///|
fn discrete_palette(name : String) -> Array[String]? {
  match name {
    "accent" =>
      Some([
        "#7fc97f", "#beaed4", "#fdc086", "#ffff99", "#386cb0", "#f0027f", "#bf5b17",
        "#666666",
      ])
    "category10" =>
      Some([
        "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2",
        "#7f7f7f", "#bcbd22", "#17becf",
      ])
    "category20" =>
      Some([
        "#1f77b4", "#aec7e8", "#ff7f0e", "#ffbb78", "#2ca02c", "#98df8a", "#d62728",
        "#ff9896", "#9467bd", "#c5b0d5", "#8c564b", "#c49c94", "#e377c2", "#f7b6d2",
        "#7f7f7f", "#c7c7c7", "#bcbd22", "#dbdb8d", "#17becf", "#9edae5",
      ])
    "category20b" =>
      Some([
        "#393b79", "#5254a3", "#6b6ecf", "#9c9ede", "#637939", "#8ca252", "#b5cf6b",
        "#cedb9c", "#8c6d31", "#bd9e39", "#e7ba52", "#e7cb94", "#843c39", "#ad494a",
        "#d6616b", "#e7969c", "#7b4173", "#a55194", "#ce6dbd", "#de9ed6",
      ])
    "category20c" =>
      Some([
        "#3182bd", "#6baed6", "#9ecae1", "#c6dbef", "#e6550d", "#fd8d3c", "#fdae6b",
        "#fdd0a2", "#31a354", "#74c476", "#a1d99b", "#c7e9c0", "#756bb1", "#9e9ac8",
        "#bcbddc", "#dadaeb", "#636363", "#969696", "#bdbdbd", "#d9d9d9",
      ])
    "dark2" =>
      Some([
        "#1b9e77", "#d95f02", "#7570b3", "#e7298a", "#66a61e", "#e6ab02", "#a6761d",
        "#666666",
      ])
    "observable10" =>
      Some([
        "#4269d0", "#efb118", "#ff725c", "#6cc5b0", "#3ca951", "#ff8ab7", "#a463f2",
        "#97bbf5", "#9c6b4e", "#9498a0",
      ])
    "paired" =>
      Some([
        "#a6cee3", "#1f78b4", "#b2df8a", "#33a02c", "#fb9a99", "#e31a1c", "#fdbf6f",
        "#ff7f00", "#cab2d6", "#6a3d9a", "#ffff99", "#b15928",
      ])
    "pastel1" =>
      Some([
        "#fbb4ae", "#b3cde3", "#ccebc5", "#decbe4", "#fed9a6", "#ffffcc", "#e5d8bd",
        "#fddaec", "#f2f2f2",
      ])
    "pastel2" =>
      Some([
        "#b3e2cd", "#fdcdac", "#cbd5e8", "#f4cae4", "#e6f5c9", "#fff2ae", "#f1e2cc",
        "#cccccc",
      ])
    "set1" =>
      Some([
        "#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#ffff33", "#a65628",
        "#f781bf", "#999999",
      ])
    "set2" =>
      Some([
        "#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#ffd92f", "#e5c494",
        "#b3b3b3",
      ])
    "set3" =>
      Some([
        "#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69",
        "#fccde5", "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f",
      ])
    "tableau10" =>
      Some([
        "#4c78a8", "#f58518", "#e45756", "#72b7b2", "#54a24b", "#eeca3b", "#b279a2",
        "#ff9da6", "#9d755d", "#bab0ac",
      ])
    "tableau20" =>
      Some([
        "#4c78a8", "#9ecae9", "#f58518", "#ffbf79", "#54a24b", "#88d27a", "#b79a20",
        "#f2cf5b", "#439894", "#83bcb6", "#e45756", "#ff9d98", "#79706e", "#bab0ac",
        "#d67195", "#fcbfd2", "#b279a2", "#d6a5c9", "#9e765f", "#d8b5a5",
      ])
    _ => None
  }
}

///|
fn continuous_palette(name : String) -> Array[String]? {
  match name {
    "blues" =>
      Some([
        "#cfe1f2", "#bed8ec", "#a8cee5", "#8fc1de", "#74b2d7", "#5ba3cf", "#4592c6",
        "#3181bd", "#206fb2", "#125ca4", "#0a4a90",
      ])
    "greens" =>
      Some([
        "#d3eecd", "#c0e6ba", "#abdda5", "#94d391", "#7bc77d", "#60ba6c", "#46ab5e",
        "#329a51", "#208943", "#0e7735", "#036429",
      ])
    "greys" =>
      Some([
        "#e2e2e2", "#d4d4d4", "#c4c4c4", "#b1b1b1", "#9d9d9d", "#888888", "#757575",
        "#626262", "#4d4d4d", "#353535", "#1e1e1e",
      ])
    "oranges" =>
      Some([
        "#fdd8b3", "#fdc998", "#fdb87b", "#fda55e", "#fc9244", "#f87f2c", "#f06b18",
        "#e4580b", "#d14904", "#b93d02", "#9f3303",
      ])
    "purples" =>
      Some([
        "#e2e1ef", "#d4d4e8", "#c4c5e0", "#b4b3d6", "#a3a0cc", "#928ec3", "#827cb9",
        "#7566ae", "#684ea2", "#5c3696", "#501f8c",
      ])
    "reds" =>
      Some([
        "#fdc9b4", "#fcb49a", "#fc9e80", "#fc8767", "#fa7051", "#f6573f", "#ec3f2f",
        "#dc2a25", "#c81b1d", "#b21218", "#970b13",
      ])
    "bluegreen" =>
      Some([
        "#d5efed", "#c1e8e0", "#a7ddd1", "#8bd2be", "#70c6a9", "#58ba91", "#44ad77",
        "#319c5d", "#208946", "#0e7736", "#036429",
      ])
    "bluepurple" =>
      Some([
        "#ccddec", "#bad0e4", "#a8c2dd", "#9ab0d4", "#919cc9", "#8d85be", "#8b6db2",
        "#8a55a6", "#873c99", "#822287", "#730f71",
      ])
    "greenblue" =>
      Some([
        "#d3eece", "#c5e8c3", "#b1e1bb", "#9bd8bb", "#82cec2", "#69c2ca", "#51b2cd",
        "#3c9fc7", "#288abd", "#1675b1", "#0b60a1",
      ])
    "orangered" =>
      Some([
        "#fddcaf", "#fdcf9b", "#fdc18a", "#fdad77", "#fb9562", "#f67d53", "#ee6545",
        "#e24932", "#d32d1e", "#bf130d", "#a70403",
      ])
    "purpleblue" =>
      Some([
        "#dbdaeb", "#c8cee4", "#b1c3de", "#97b7d8", "#7bacd1", "#5b9fc9", "#3a90c0",
        "#1e7fb7", "#0b70ab", "#056199", "#045281",
      ])
    "purplebluegreen" =>
      Some([
        "#dbd8ea", "#c8cee4", "#b0c3de", "#93b7d8", "#72acd1", "#549fc8", "#3892bb",
        "#1c88a3", "#097f87", "#02736b", "#016353",
      ])
    "purplered" =>
      Some([
        "#dcc9e2", "#d3b3d7", "#ce9ecc", "#d186c0", "#da6bb2", "#e14da0", "#e23189",
        "#d91e6f", "#c61159", "#ab0749", "#8f023a",
      ])
    "redpurple" =>
      Some([
        "#fccfcc", "#fcbec0", "#faa9b8", "#f98faf", "#f571a5", "#ec539d", "#db3695",
        "#c41b8a", "#a90880", "#8d0179", "#700174",
      ])
    "yellowgreen" =>
      Some([
        "#e4f4ac", "#d1eca0", "#b9e294", "#9ed688", "#80c97c", "#62bb6e", "#47aa5e",
        "#329750", "#208344", "#0e723b", "#036034",
      ])
    "yelloworangebrown" =>
      Some([
        "#feeaa1", "#fedd84", "#fecc63", "#feb746", "#fca031", "#f68921", "#eb7215",
        "#db5e0b", "#c54c05", "#ab3d03", "#8f3204",
      ])
    "yelloworangered" =>
      Some([
        "#fee087", "#fed16f", "#febd59", "#fea849", "#fd903e", "#fc7335", "#f9522b",
        "#ee3423", "#de1b20", "#ca0b22", "#af0225",
      ])
    "blueorange" =>
      Some([
        "#134b85", "#2f78b3", "#5da2cb", "#9dcae1", "#d2e5ef", "#f2f0eb", "#fce0ba",
        "#fbbf74", "#e8932f", "#c5690d", "#994a07",
      ])
    "brownbluegreen" =>
      Some([
        "#704108", "#a0651a", "#c79548", "#e3c78a", "#f3e6c6", "#eef1ea", "#c9e9e4",
        "#8ed1c7", "#4da79e", "#187a72", "#025147",
      ])
    "purplegreen" =>
      Some([
        "#5b1667", "#834792", "#a67fb6", "#c9aed3", "#e6d6e8", "#eff0ef", "#d9efd5",
        "#aedda9", "#71bb75", "#368e49", "#0e5e29",
      ])
    "purpleorange" =>
      Some([
        "#411469", "#664796", "#8f83b7", "#b9b4d6", "#dadbeb", "#f3eeea", "#fce0ba",
        "#fbbf74", "#e8932f", "#c5690d", "#994a07",
      ])
    "redblue" =>
      Some([
        "#8c0d25", "#bf363a", "#df745e", "#f4ae91", "#fbdbc9", "#f2efee", "#d2e5ef",
        "#9dcae1", "#5da2cb", "#2f78b3", "#134b85",
      ])
    "redgrey" =>
      Some([
        "#8c0d25", "#bf363a", "#df745e", "#f4ae91", "#fcdccb", "#faf4f1", "#e2e2e2",
        "#c0c0c0", "#969696", "#646464", "#343434",
      ])
    "yellowgreenblue" =>
      Some([
        "#eff9bd", "#dbf1b4", "#bde5b5", "#94d5b9", "#69c5be", "#45b4c2", "#2c9ec0",
        "#2182b8", "#2163aa", "#23479c", "#1c3185",
      ])
    "redyellowblue" =>
      Some([
        "#a50026", "#d4322c", "#f16e43", "#fcac64", "#fedd90", "#faf8c1", "#dcf1ec",
        "#abd6e8", "#75abd0", "#4a74b4", "#313695",
      ])
    "redyellowgreen" =>
      Some([
        "#a50026", "#d4322c", "#f16e43", "#fcac63", "#fedd8d", "#f9f7ae", "#d7ee8e",
        "#a4d86e", "#64bc61", "#22964f", "#006837",
      ])
    "pinkyellowgreen" =>
      Some([
        "#8e0152", "#c0267e", "#dd72ad", "#f0b3d6", "#fadded", "#f5f3ef", "#e1f2ca",
        "#b6de87", "#80bb47", "#4f9125", "#276419",
      ])
    "spectral" =>
      Some([
        "#9e0142", "#d13c4b", "#f0704a", "#fcac63", "#fedd8d", "#fbf8b0", "#e0f3a1",
        "#a9dda2", "#69bda9", "#4288b5", "#5e4fa2",
      ])
    "viridis" =>
      Some([
        "#440154", "#470e61", "#481a6c", "#482575", "#472f7d", "#443a83", "#414487",
        "#3d4e8a", "#39568c", "#35608d", "#31688e", "#2d708e", "#2a788e", "#27818e",
        "#23888e", "#21918d", "#1f988b", "#1fa088", "#22a884", "#2ab07f", "#35b779",
        "#43bf71", "#54c568", "#66cc5d", "#7ad151", "#8fd744", "#a5db36", "#bcdf27",
        "#d2e21b", "#e9e51a", "#fde725",
      ])
    "magma" =>
      Some([
        "#000004", "#040413", "#0b0924", "#150e37", "#20114b", "#2c1160", "#3b0f70",
        "#4a1079", "#57157e", "#651a80", "#721f81", "#7f2482", "#8c2981", "#9a2e80",
        "#a8327d", "#b6377a", "#c43c75", "#d1426f", "#de4968", "#e95462", "#f1605d",
        "#f76f5c", "#fa7f5e", "#fc8f65", "#fe9f6d", "#feaf78", "#febf84", "#fece91",
        "#fddea0", "#fcedaf", "#fcfdbf",
      ])
    "inferno" =>
      Some([
        "#000004", "#040313", "#0c0826", "#170c3b", "#240c4f", "#330a5f", "#420a68",
        "#500d6c", "#5d126e", "#6b176e", "#781c6d", "#86216b", "#932667", "#a12b62",
        "#ae305c", "#bb3755", "#c73e4c", "#d24644", "#dd513a", "#e65c30", "#ed6925",
        "#f3771a", "#f8850f", "#fb9506", "#fca50a", "#fcb519", "#fac62d", "#f6d645",
        "#f2e661", "#f3f484", "#fcffa4",
      ])
    "plasma" =>
      Some([
        "#0d0887", "#230690", "#330597", "#42039d", "#5002a2", "#5d01a6", "#6a00a8",
        "#7801a8", "#8405a7", "#900da4", "#9c179e", "#a72198", "#b12a90", "#ba3488",
        "#c33d80", "#cb4779", "#d35171", "#da5a69", "#e16462", "#e76e5b", "#ed7953",
        "#f2834c", "#f68f44", "#fa9a3d", "#fca636", "#fdb32f", "#fec029", "#fcce25",
        "#f9dc24", "#f5ea27", "#f0f921",
      ])
    "cividis" =>
      Some([
        "#002051", "#002358", "#00265d", "#002961", "#012b65", "#042e67", "#083169",
        "#0d346b", "#11366c", "#16396d", "#1c3c6e", "#213f6e", "#26426e", "#2c456e",
        "#31476e", "#374a6e", "#3c4d6e", "#42506e", "#47536d", "#4c566d", "#51586e",
        "#555b6e", "#5a5e6e", "#5e616e", "#62646f", "#66676f", "#6a6a70", "#6e6d71",
        "#727071", "#757372", "#797673", "#7c7974", "#7f7c75", "#827f75", "#868276",
        "#898577", "#8c8877", "#908b78", "#938e78", "#969178", "#9a9478", "#9e9778",
        "#a19b78", "#a59e77", "#a9a177", "#aea575", "#b2a874", "#b6ab73", "#bbaf71",
        "#c0b26f", "#c5b66d", "#c9b96a", "#cebd68", "#d3c065", "#d8c462", "#ddc85f",
        "#e2cb5c", "#e7cf58", "#ebd355", "#f0d652", "#f3da4f", "#f7de4c", "#fae249",
        "#fce647",
      ])
    "rainbow" =>
      Some([
        "#6e40aa", "#883eb1", "#a43db3", "#bf3caf", "#d83fa4", "#ee4395", "#fe4b83",
        "#ff576e", "#ff6659", "#ff7847", "#ff8c38", "#f3a130", "#e2b72f", "#cfcc36",
        "#bee044", "#aff05b", "#8ff457", "#6ff65b", "#52f667", "#3af278", "#28ea8d",
        "#1ddfa3", "#19d0b8", "#1cbecb", "#23abd8", "#2f96e0", "#3d82e1", "#4c6edb",
        "#5a5dd0", "#664dbf", "#6e40aa",
      ])
    "sinebow" =>
      Some([
        "#ff4040", "#fc582a", "#f47218", "#e78d0b", "#d5a703", "#bfbf00", "#a7d503",
        "#8de70b", "#72f418", "#58fc2a", "#40ff40", "#2afc58", "#18f472", "#0be78d",
        "#03d5a7", "#00bfbf", "#03a7d5", "#0b8de7", "#1872f4", "#2a58fc", "#4040ff",
        "#582afc", "#7218f4", "#8d0be7", "#a703d5", "#bf00bf", "#d503a7", "#e70b8d",
        "#f41872", "#fc2a58", "#ff4040",
      ])
    "turbo" =>
      Some([
        "#23171b", "#32204a", "#3e2a71", "#453493", "#493eae", "#4b49c5", "#4a53d7",
        "#485ee4", "#4569ee", "#4074f5", "#3c7ff8", "#378af9", "#3295f7", "#2e9ff4",
        "#2ba9ef", "#28b3e9", "#26bce1", "#25c5d9", "#25cdcf", "#27d5c6", "#29dcbc",
        "#2de3b2", "#32e9a7", "#38ee9d", "#3ff393", "#47f689", "#50f980", "#5afc77",
        "#65fd6e", "#70fe66", "#7cfd5e", "#88fc57", "#95fb51", "#a1f84b", "#adf545",
        "#b9f140", "#c5ec3c", "#d0e637", "#dae034", "#e4d931", "#ecd12e", "#f4c92b",
        "#fac029", "#ffb626", "#ffad24", "#ffa223", "#ff9821", "#ff8d1f", "#ff821d",
        "#ff771c", "#fd6c1a", "#f76118", "#f05616", "#e84b14", "#df4111", "#d5380f",
        "#cb2f0d", "#c0260a", "#b61f07", "#ac1805", "#a31302", "#9b0f00", "#950c00",
        "#910b00",
      ])
    "browns" =>
      Some([
        "#eedbbd", "#ecca96", "#e9b97a", "#e4a865", "#dc9856", "#d18954", "#c7784c",
        "#c0673f", "#b85536", "#ad4433", "#9f3632",
      ])
    "tealblues" =>
      Some([
        "#bce4d8", "#9dd3d1", "#81c3cb", "#65b3c2", "#45a2b9", "#368fae", "#347da0",
        "#306a93", "#2c5985",
      ])
    "teals" =>
      Some([
        "#bbdfdf", "#a2d4d5", "#8ac9c9", "#75bcbb", "#61b0af", "#4da5a4", "#379998",
        "#2b8b8c", "#1e7f7f", "#127273", "#006667",
      ])
    "warmgreys" =>
      Some([
        "#dcd4d0", "#cec5c1", "#c0b8b4", "#b3aaa7", "#a59c99", "#98908c", "#8b827f",
        "#7e7673", "#726866", "#665c5a", "#59504e",
      ])
    "goldgreen" =>
      Some([
        "#f4d166", "#d5ca60", "#b6c35c", "#98bb59", "#7cb257", "#60a656", "#4b9c53",
        "#3f8f4f", "#33834a", "#257740", "#146c36",
      ])
    "goldorange" =>
      Some([
        "#f4d166", "#f8be5c", "#f8aa4c", "#f5983b", "#f3852a", "#ef701b", "#e2621f",
        "#d65322", "#c54923", "#b14223", "#9e3a26",
      ])
    "goldred" =>
      Some([
        "#f4d166", "#f6be59", "#f9aa51", "#fc964e", "#f6834b", "#ee734a", "#e56249",
        "#db5247", "#cf4244", "#c43141", "#b71d3e",
      ])
    "lightgreyred" =>
      Some([
        "#efe9e6", "#e1dad7", "#d5cbc8", "#c8bdb9", "#bbaea9", "#cd967d", "#dc7b43",
        "#e15f19", "#df4011", "#dc000b",
      ])
    "lightgreyteal" =>
      Some([
        "#e4eaea", "#d6dcdd", "#c8ced2", "#b7c2c7", "#a6b4bc", "#64b0bf", "#22a6c3",
        "#2295c1", "#1f85be", "#1876bc",
      ])
    "lightmulti" =>
      Some([
        "#e0f1f2", "#c4e9d0", "#b0de9f", "#d0e181", "#f6e072", "#f6c053", "#f3993e",
        "#f77440", "#ef4a3c",
      ])
    "lightorange" =>
      Some([
        "#f2e7da", "#f7d5ba", "#f9c499", "#fab184", "#fa9c73", "#f68967", "#ef7860",
        "#e8645b", "#de515b", "#d43d5b",
      ])
    "lighttealblue" =>
      Some([
        "#e3e9e0", "#c0dccf", "#9aceca", "#7abfc8", "#59afc0", "#389fb9", "#328dad",
        "#2f7ca0", "#276b95", "#255988",
      ])
    "darkblue" =>
      Some([
        "#323232", "#2d4668", "#1a5c93", "#0074af", "#008cbf", "#05a7ce", "#25c0dd",
        "#38daed", "#50f3fa", "#ffffff",
      ])
    "darkgold" =>
      Some([
        "#3c3c3c", "#584b37", "#725e34", "#8c7631", "#ae8b2b", "#cfa424", "#ecc31e",
        "#f9de30", "#fff184", "#ffffff",
      ])
    "darkgreen" =>
      Some([
        "#3a3a3a", "#215748", "#006f4d", "#048942", "#489e42", "#76b340", "#a6c63d",
        "#d2d836", "#ffeb2c", "#ffffaa",
      ])
    "darkmulti" =>
      Some([
        "#373737", "#1f5287", "#197d8c", "#29a869", "#95ce3f", "#ffe800", "#ffffff",
      ])
    "darkred" =>
      Some([
        "#343434", "#703633", "#9e3c38", "#cc4037", "#e75d1e", "#ec8620", "#eeab29",
        "#f0ce32", "#ffeb2c",
      ])
    _ => None
  }
}

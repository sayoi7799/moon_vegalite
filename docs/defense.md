# 答辩要点

moon_vegalite 是 Vega-Lite 的 MoonBit 实现：输入一份 Vega-Lite JSON，输出一棵带包围盒的场景图和一份 SVG，目标是和官方
vega-lite 5.23.0 + vega 5.33.1 的输出**逐项一致**，不是风格接近。下面每一点都指出了对应的文件或测试。

## 1. 整体流程

规格 → 数据变换 → 比例尺 → 坐标轴和图例 → 场景图 → SVG。

- **规格**（`spec/`）：严格的 JSON 读取器。认识的特性变成类型化的结构，不认识或没实现的直接报错并给出 JSON 路径，所以不会"悄悄画成别的样子"（`vl/validate.mbt`、`vl/errors_test.mbt`）。
- **数据变换**（`vl/unit.mbt` 的 `build_unit`、`transform/`）：日期解析、`calculate` / `filter`、`timeUnit`、`bin`、`aggregate`、堆叠、过滤无效值，顺序和 vega-lite 编译出的 Vega 规格一致。
- **比例尺**（`scale/`）：线性、对数、幂、时间、band、point、ordinal、颜色色板，定义域和值域的规则都是移植的。
- **坐标轴和图例**（`vl/axis.mbt`、`vl/legend.mbt`、`vl/channels.mbt`）：刻度、标签、标题、图例的生成和布局。
- **场景图**（`scene/`）：和 vega-scenegraph 同构的一棵树，每个图元带包围盒；这是后端无关的中间表示，SVG 只是它的一种渲染（`svg/`）。
- **没有中间的 Vega 规格**：不是先编译成 Vega 再解释，而是把 vega-lite 的编译决策和 vega 里决定外观的那部分算法直接移植过来，所以代码量小，代价是只能做静态图。

## 2. 为什么能和官方 SVG 完全一致

一个刻度值差一位，标签文字就不一样，所以每个会进入数字的环节都按官方的行为做：

- **d3 的刻度和格式**：刻度和 `nice` 来自 d3-array（`stats/ticks.mbt`），数字格式按 vega 实际打包的 d3-format 3.1.0 移植（`format/d3format.mbt`；单独装的 3.1.2 行为不同），时间刻度和格式来自 d3-time / d3-time-format（`time/`）。
- **JavaScript 的数值语义**：`String(x)` 的最短往返输出、`Math.round`、`~~x` 截断、`Math.min / max` 对 NaN 的处理（`util/jsnum.mbt`），MoonBit 不保证这些，所以自己实现并用 Node 对照。
- **V8 兼容的数学函数**：不同平台的 C 库和 V8 在个别参数上差 1 ulp。`Math.log`、`log10`、`acos`、`atan2` 移植自 fdlibm（`util/fdlibm.mbt`、`util/v8math.mbt`）；`10^k` 用查表，表里是正确舍入的值（`util/pow10_table.mbt`，因为 V8 的 `Math.pow` 自己在 Linux、macOS、Windows 之间也不一致）；整数角度的 `sin` / `cos` 查表；弧形用的 `sin`、`cos`、`asin` 来自 moon_rough 里和 V8 逐位一致的实现。全部用 Node 的 `Math` 生成的数据逐位对照。
- **文字宽度估算**：没有 Canvas 时 vega 用 `~~(0.8 * 字数 * 字号)` 估算宽度，再经过旋转和 `Math.ceil` 进入布局，所以必须逐位一致才能得到相同的坐标轴留白（`scene/text.mbt`）。演示页里官方一侧也关掉了浏览器的 canvas 测量，用同样的估算，两边才能逐字比较。
- **流水线的顺序**：比如无效值什么时候过滤、堆叠在聚合之前还是之后、堆叠面积图要不要补零，都是对着官方编译出的 Vega 规格一项项核对的。

## 3. 测试方法

- **预期值只来自官方包**：`scripts/gen_fixtures.mjs` 用 Node 24 在 `TZ=UTC` 下调用官方 vega-lite 5.23.0、vega 5.33.1，版本锁在 `scripts/package-lock.json`，把结果生成成 MoonBit 源文件放在 `fixtures/`。仓库里没有一个预期值是手写的。
- **分层对照**：底层有数字格式、刻度、`nice`、时间格式、比例尺、表达式、数据变换、场景图包围盒和 SVG 的对照数据（逐位的十六进制 double 或随机场景）；最上层是端到端：80 个官方示例、边界用例（空数据、全空列、单值定义域、含非正值的对数轴）和 MoonFrame 生成的规格，规格 → 场景图 → SVG 分别和官方比。
- **比较什么**：场景图里每个图元的每个属性和包围盒（数值允许 1e-9 的相对误差），SVG 文本逐字相同（只忽略无障碍属性）。手绘版则是和"官方 vega-lite + vega + rough.js 4.6.6"的输出逐字节相同（`scripts/lib/sketch.mjs`、`fixtures/sketchcases`）。
- **怎么保证不退化**：CI 在 Linux、macOS、Windows 上跑 js、wasm-gc、native 三个后端；`fixtures` 任务会重新生成全部数据，只要和已提交的有任何不同就失败。新特性的做法一直是：先找出和官方对不上的最小例子，改到逐项一致，再把它加进对照。
- **不支持的写法也是测试对象**：`vl/errors_test.mbt` 检查每一类不支持的写法都带路径报错。

## 4. 和 MoonFrame、moon_rough 的关系，以及和同类库的区别

- **MoonFrame**（DataFrame 库）：它的 `format_vega_lite` 能把 DataFrame 导出成 Vega-Lite 规格，导出之后却没有地方可以渲染。moon_vegalite 补的就是渲染这一步：`examples/moonframe` 里是 MoonFrame 生成的规格（也是测试输入），`examples/moonframe_demo` 是完整流程，读 CSV、汇总、生成规格、直接渲染成 SVG，不需要打开 Vega 编辑器。
- **moon_rough**（rough.js 4.6.6 的 MoonBit 移植，我的另一个项目）：手绘风格靠它。`svg` 渲染器把每个矩形、线、路径、符号、弧形交给一个回调，`sketch` 包用 moon_rough 来画，文字不变；每个图形的 seed 由基础 seed 和它在场景图里的位置派生，所以同样的规格和 seed 输出逐字节相同。moon_rough 自己和 rough.js 逐位一致，moon_vegalite 再和"官方 vega-lite + rough.js"逐字节对照。
- **和同类 MoonBit 图表库的区别**：我查到的几个（[lfegg/MoonChart](https://github.com/lfegg/MoonChart)：折线和柱状图，基于 CAIMEOX/svg，README 标为 WIP；[Mitsuha/MoonChartSVG](https://www.gitlink.org.cn/Mitsuha/MoonChartSVG)：零依赖，九种图表，builder API；[JunJunTvT/moonchart](https://www.gitlink.org.cn/JunJunTvT/moonchart)：柱、线、散点和带误差线的箱线图）都有自己的 API，用代码一个个拼图表。moon_vegalite 的输入是 **Vega-Lite 规格**，一个现成的、很多工具（包括 MoonFrame、大模型）都能生成的标准格式；它做的不是"也能画图"，而是"画得和官方一模一样"，并且能证明这一点（上面的第 3 点）；中间有公开的场景图，不只是 SVG；不支持的写法会报出 JSON 路径，可以直接反馈给大模型修正（`examples/llm_feedback`）。反过来，它只实现了 Vega-Lite 的一个子集，那些库里有而它没有的图表类型（比如雷达图、箱线图）它画不了。

## 5. 如实说明的几点

- 还没有发布到 mooncakes.io，目前通过 `moon.work` 使用本地检出的源码。
- 只实现了 Vega-Lite 的子集，边界在 README 的 Support 表里，每一项不支持的都会报错。
- 性能：1 万行聚合柱状图上比 Node 里的 vega 慢（wasm-gc / js 约 1.5 到 1.6 倍），10 万点散点图上 wasm-gc / js 与 vega 相当，native 约比 wasm-gc / js 慢一倍；只做了测量，没有调查和优化（README 的"性能"）。
- MoonFrame 示例需要先跑 `setup.sh`，因为 MoonFrame 0.7.0 和它的依赖还带着旧版 `moon.mod.json`，所以这个示例不在 CI 里。
- 本地时间一律按 UTC 处理，测试也在 `TZ=UTC` 下生成。

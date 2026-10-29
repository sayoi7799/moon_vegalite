# moon_vegalite

[English](README.md)

用 MoonBit 写的、由规格驱动的 [Vega-Lite](https://vega.github.io/vega-lite/) 渲染器。
输入一段 Vega-Lite JSON 规格，输出与后端无关的**场景图（scenegraph）**和一份 **SVG**。
支持 `wasm-gc`、`js`、`native` 三个后端；库本身只依赖 MoonBit 核心库
（只有命令行工具 `vl2svg` 为了读写文件用到了 `moonbitlang/x`）。

## 快速开始

输入 Vega-Lite 规格（JSON 文本），输出 SVG 文档
（完整可运行的工程见 [`examples/hello`](examples/hello)）：

```moonbit
let spec : String =
  #|{
  #|  "data": {"values": [{"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43}]},
  #|  "mark": "bar",
  #|  "encoding": {
  #|    "x": {"field": "a", "type": "nominal"},
  #|    "y": {"field": "b", "type": "quantitative"}
  #|  }
  #|}

fn main {
  let svg = @moon_vegalite.render_svg(spec) catch {
    e => {
      println("error: " + e.message())   // 遇到不支持的特性时，错误信息会给出 JSON 路径
      return
    }
  }
  println(svg)
}
```

```sh
git clone https://github.com/sayoi7799/moon_vegalite
cd moon_vegalite/examples/hello
moon run cmd > bar.svg                     # 用浏览器打开 bar.svg
```

用本仓库的命令行工具 `vl2svg` 画同一张图：

```sh
cd moon_vegalite
moon run cmd/vl2svg --target native -- examples/bar_basic.vl.json bar.svg   # 写出 SVG 文件（不给第二个参数则输出到标准输出）
moon run cmd/vl2svg --target native -- --scene examples/bar_basic.vl.json   # 输出场景图 JSON，含每个图元的包围盒
```

库的接口（`moon_vegalite.mbt`）：

```moonbit
let svg = @moon_vegalite.render_svg(spec_json)        // SVG 文档
let c = @moon_vegalite.compile(spec_json)             // 场景图 + 视图信息
let scene = @moon_vegalite.scene_json(c)              // 场景图的 JSON 形式
```

### 安装

环境要求：[MoonBit 工具链](https://www.moonbitlang.com/download/)（开发和测试使用 `moon 0.1.20261016`）。

模块 `sayoi7799/moon_vegalite` 目前还没有发布到 mooncakes.io，所以通过 `moon.work` 工作区使用本地检出的源码。
在你自己的模块里这样写（完整目录结构见 [`examples/hello`](examples/hello)）：

```
// moon.mod
import {
  "sayoi7799/moon_vegalite@0.1.0",
}
```

```
// moon.work，和你的 moon.mod 放在一起
members = [
  ".",
  "../moon_vegalite",   // 本仓库的检出目录
]
```

```
// 你的包的 moon.pkg
import {
  "sayoi7799/moon_vegalite",
}
```

仓库：[GitHub](https://github.com/sayoi7799/moon_vegalite) · [GitLink](https://gitlink.org.cn/sayoi7799/moon_vegalite)。

## 在线演示

**<https://sayoi7799.github.io/moon_vegalite/>**：修改 Vega-Lite 规格，实时看到本库（编译成 JavaScript，运行在你的浏览器里）渲染的 SVG，
旁边是官方 vega-embed 的渲染结果，并有标签说明两边的 SVG 文本是否逐字相同。示例包括官方图表、分层图、
MoonFrame 生成的规格，以及几个不支持的特性（会显示带 JSON 路径的错误）。页面由 `.github/workflows/pages.yml`
用 [`site/`](site) 和 `web` 包（`moon build --target js --release`）构建；本地运行：

```sh
moon build --target js --release
node scripts/build_site.mjs && node scripts/serve_site.mjs     # http://localhost:8080/
```

## 用 MoonFrame 从 CSV 生成图表

[`examples/moonframe_demo`](examples/moonframe_demo) 用 [MoonFrame](https://github.com/ihb2032/MoonFrame) 读取 CSV 并做汇总，
由 MoonFrame 生成 Vega-Lite 规格，再用本库直接渲染成 SVG，整个过程是一个 MoonBit 程序，不需要打开 Vega 编辑器。
它写出的三张 SVG 与官方 vega 的输出逐字相同。MoonFrame 0.7.0 在当前工具链下需要一步准备工作，
由示例里的 `setup.sh` 完成，示例自己的 README 里有说明。

## 与官方输出并排对照

左：本库；右：vega-lite 5.23.0 + vega 5.33.1。除无障碍属性外，SVG 文本逐字相同。
直接用浏览器打开 [`gallery/index.html`](gallery/index.html)（不需要启动服务器）可以看到全部 30 张图。

![画廊页面](docs/gallery.png)

| 图 | moon_vegalite | 官方 vega |
| --- | --- | --- |
| `stacked_bar_v` | <img src="gallery/ours/stacked_bar_v.svg" width="320" alt="moon_vegalite: stacked_bar_v"> | <img src="gallery/official/stacked_bar_v.svg" width="320" alt="vega: stacked_bar_v"> |
| `point_color` | <img src="gallery/ours/point_color.svg" width="320" alt="moon_vegalite: point_color"> | <img src="gallery/official/point_color.svg" width="320" alt="vega: point_color"> |
| `layer_bar_line` | <img src="gallery/ours/layer_bar_line.svg" width="320" alt="moon_vegalite: layer_bar_line"> | <img src="gallery/official/layer_bar_line.svg" width="320" alt="vega: layer_bar_line"> |
| `layer_histogram` | <img src="gallery/ours/layer_histogram.svg" width="320" alt="moon_vegalite: layer_histogram"> | <img src="gallery/official/layer_histogram.svg" width="320" alt="vega: layer_histogram"> |
| `layer_color_legend_left` | <img src="gallery/ours/layer_color_legend_left.svg" width="320" alt="moon_vegalite: layer_color_legend_left"> | <img src="gallery/official/layer_color_legend_left.svg" width="320" alt="vega: layer_color_legend_left"> |
| `layer_circle_independent_color` | <img src="gallery/ours/layer_circle_independent_color.svg" width="320" alt="moon_vegalite: layer_circle_independent_color"> | <img src="gallery/official/layer_circle_independent_color.svg" width="320" alt="vega: layer_circle_independent_color"> |

## 定位，以及与其他图表库的区别

* **跟随 Vega-Lite，而不是另起一套语法。** 目标是画出与参考实现（vega-lite 5.23.0 + vega 5.33.1）相同的图，而不是相似的图：
  坐标轴刻度、标签格式、图例、布局和图元包围盒都移植自 vega-lite / vega，包括它们在 JavaScript 数字和文字度量上的行为。
* **场景图优先。** 和 Vega 一样，库先生成一棵带有包围盒的图元树；SVG 只是这棵树的一种渲染器，别的后端也可以消费它。
  多数 MoonBit 绘图代码直接画图，这里的中间表示是公开的。
* **规格进，图片出。** 图表就是数据（JSON），可以来自别的工具。测试会把
  [MoonFrame](https://github.com/ihb2032/MoonFrame)（`DataFrame` → Vega-Lite）生成的规格交给渲染器。
* **不需要浏览器，不需要 JavaScript 运行时。** 渲染是一个纯函数，可用于原生命令行、WebAssembly 或 JS。
* **如实说明范围。** 这是一个子集渲染器。子集之外的内容会报错并给出 JSON 路径
  （如 `encoding.color.condition 暂不支持`），而不是悄悄画成别的样子。

## 支持范围

| 方面 | 支持内容 |
| --- | --- |
| 标记（mark） | `bar`、`line`、`point`、`circle`、`square`、`area`、`rule`、`tick`、`rect`、`text` |
| 通道 | `x`、`y`（字段或数值 `datum`）、`x2`、`y2`（用于 `rule`、`bar`、`rect`）、`color`（名义字段用分类色板，有序字段按取值个数从 blues 色带取样，定量字段用 blues 渐变并配渐变图例，常量值）、`size`、`opacity`、`shape`、`text`（`point`、`circle`、`square` 上的大小、透明度和形状；定量字段得到连续比例尺，形状为名义型） |
| 字段类型 | `quantitative`、`ordinal`、`nominal`、`temporal` |
| 聚合 | `count`、`sum`、`mean`、`average`、`min`、`max`、`median`、`distinct` 等（vega 的聚合操作） |
| 变换 | `filter`（表达式或谓词）、`calculate`（表达式子集）、`aggregate`、`bin`、`timeUnit`、`fold`；字段上的 `bin`、`timeUnit`、`aggregate` |
| 时间单位 | year、quarter、month、week、date、day、hours、minutes、seconds、milliseconds 及其组合（按 UTC；"本地时间"即 UTC） |
| 比例尺 | `linear`、`log`、`sqrt`、`pow`、`time`、`utc`、`band`、`point`、`ordinal`（`domain`、`range`、`zero`、`nice`、`reverse`、`clamp`、`base`、`exponent`） |
| 堆叠 | `bar` 和 `area` 默认堆叠；`stack: zero / center / normalize / null` |
| 排序 | 离散 x / y 上的 `sort`：`ascending`、`descending`、取值列表、`-x` / `-y`、`{op, field, order}` |
| 分层（layer） | 位置比例尺默认共享（合并定义域，band 比例尺优先于 point）；`resolve.scale.x / y: independent` 让每层有自己的比例尺和坐标轴，第二根轴放到另一侧；颜色比例尺及其图例默认共享，也可用 `resolve.scale.color` 独立；对同一字段做相同 `bin` 的各层共用一次分箱（在公共数据上计算，与 vega-lite 提升分箱的做法一致）和一个分箱比例尺；各层的 mark 命名为 `layer_0_marks` 等 |
| 辅助元素 | 坐标轴（网格、刻度、带首尾对齐和重叠剔除的标签、标题）、符号图例、图表标题 |
| 布局 | 单视图或 `layer`（嵌套分层，继承 `data` / `transform` / `encoding`，`resolve.scale` / `legend`），`autosize: pad`，`width` / `height` 取数字或 `{step}` |
| 配置 | 接受的键会被记录；其中一部分（`view`、`scale.zero` 等）会生效 |

不支持——每一项都会报错并给出 JSON 路径：`params` / `selection`、`tooltip`、`projection`、`facet`、
`concat`（`hconcat` / `vconcat`）、`repeat`、`data.url`（请改用内嵌的 `data.values`）、`condition`，
以及完整的 Vega 表达式语言（只实现了 `calculate` / `filter` 用到的子集）。
定量颜色的渐变图例只支持默认的 blues 色带（非位置通道上不支持 `scale` 选项）。
凡是编译器本来会忽略的内容一律报错并给出路径：未知的 mark 属性、`scale.zero` 以外的 `config` 键、
尚未实现的坐标轴 / 比例尺 / 图例选项、其他通道上的 `sort` 等（见 `vl/validate.mbt`）。

## 与官方实现的一致性

测试里所有期望值都来自官方包，没有一个来自本仓库自己：

| 层次 | 参照 | 位置 |
| --- | --- | --- |
| 数字格式化、刻度、`nice`、时间格式、比例尺 | vega 5.33.1 内置的 d3 / vega-format / vega-scale | `fixtures/{numfmt,ticks,formatcases,timecases,scalecases}` |
| 表达式、数据变换 | vega-expression、vega-transforms | `fixtures/{exprcases,transformcases}` |
| 场景图包围盒、SVG | vega-scenegraph | `fixtures/scenecases` |
| **端到端：78 个官方 Vega-Lite 示例（其中 15 个是 `layer_*`）、边界情况、MoonFrame 规格** | vega-lite 5.23.0 编译 + vega 场景图与 SVG | `fixtures/vlexamples` |

端到端用例要求场景图（每个 mark、每个图元属性和包围盒，数值在相对 `1e-9` 内）和 SVG 文本
（逐字相同，只忽略无障碍属性 `role` / `aria-label`）都与官方输出一致。
用例包括 `examples/official.txt` 里列出的 78 个官方示例、`examples/edge_*.vl.json` 里的边界情况、
`examples/channel_*.vl.json` 里的通道规格（空数据、全空列、单值定义域、含非正值的对数比例尺），
以及 MoonFrame 生成的六张图（`examples/moonframe`）。非法 JSON 和不支持的特性由 `vl/errors_test.mbt` 覆盖。

`moon test` 在 `wasm-gc`、`js`、`native` 上均通过。

### 测试数据的来源与重新生成

测试数据是 `scripts/gen_fixtures.mjs` 生成的 MoonBit 文件，使用 `scripts/package-lock.json` 里锁定的版本
（vega-lite 5.23.0、vega 5.33.1、vega-datasets 3.2.1）和 Node.js 24（部分期望值依赖 V8 的 `Math` 函数，所以 Node 主版本号很重要）。
进程时区固定为 UTC。

```sh
cd scripts
npm ci
npm run fixtures            # 下载 vega-lite 对应标签的示例规格，重新生成 ../fixtures
npm run gallery             # 重新生成 ../gallery（需要先 moon build --target native cmd/vl2svg）
```

CI 会重新生成测试数据，只要已提交的生成文件有任何不同就会失败。

`util/pow10_table.mbt` 保存整数 k 在 [-330, 310] 内的 10^k。它按 `Number("1e" + k)`（正确舍入的值）生成，
而不是 `Math.pow(10, k)`：V8 的 `Math.pow` 并不一致，在 Linux、macOS、Windows 版 Node 24 之间有少数指数相差一个 ulp
（Node 22 和 24 之间约有 70 个指数不同）。因此 `js_pow10` 是在大多数构建上与 V8 一致，而不是只与某一个特定构建一致。
与生成旧表的 Windows 构建相比，只有 10^23 变了，包括与官方输出端到端对照在内的完整测试保持不变。

`examples/moonframe/*.vl.json` 由 `ihb2032/MoonFrame` 0.7.0（`@chart.format_vega_lite`）生成。MoonFrame 0.7.0 目前
无法直接用最新的 MoonBit 工具链构建（它的依赖 `NyaCSV` 和 `quickcheck` 仍带着旧的 `moon.mod.json`，
`NyaCSV` 里还有三个测试用到了已被移除的 `Buffer` API），所以这些规格是在一个临时工程里，
迁移了这些清单文件并在本地删掉那三个测试后生成的。生成出的 JSON 原样提交。

## 目录结构

| 包 | 内容 |
| --- | --- |
| `util`、`stats`、`format`、`time`、`value` | 与 JavaScript 一致的数字运算（V8 libm）、d3 刻度、d3-format、时间间隔与格式、动态值 |
| `scale` | 连续、band、point、ordinal、sequential 比例尺，色板 |
| `expr`、`transform` | 表达式子集；aggregate / bin / stack / timeunit / fold / filter / formula |
| `scene`、`svg` | 场景图、mark 包围盒、路径生成、SVG 渲染器 |
| `spec` | Vega-Lite JSON 的严格读取器（不支持的特性带路径报错） |
| `vl` | 编译器：数据管线、比例尺、坐标轴、图例、布局 |
| `cmd/vl2svg` | 命令行工具（native） |

## 开发记录说明

2026 年 10 月 24 日之前的大部分工作是在本地完成的，没有逐步提交。10 月 24 日把已有代码按模块整理成提交
（底层数字与时间库、比例尺、表达式与变换、场景图与 SVG、规格读取器、编译器各阶段、测试、CI）。
当时 GitHub 上的历史被改写过一次，用来把几个后续的 CI 修复合并进一个提交。此后每一项改动都在
各自的分支上、针对一个 GitHub issue 完成，并通过关闭该 issue 的 pull request 合并。

## 许可证

Apache-2.0。部分代码移植自 vega、vega-lite 和 d3（BSD-3-Clause / ISC），详见各文件头部。

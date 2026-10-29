# Feeding the errors back to a language model

Language models often answer a chart request with Vega-Lite, and the answer is often wrong or uses something a renderer
does not support. The errors of moon_vegalite start with the **JSON path** of the offending property
(`encoding.color.condition 暂不支持`, `encoding.y.type: 未知的字段类型 quantitave`), which is exactly what a model needs to
correct itself. This example turns such an error into a prompt that can be sent straight back.

It works on **recorded replies**: no API key, no network. The library itself makes no network request; connecting a real model is
up to you (send `out/*.feedback.txt` as the next user message, take the new reply and run it again).

```
data/*.txt  recorded model replies
  └─ extract_json ─▶ render_svg ─┬─ ok     ▶ out/<name>.svg
                                 └─ error  ▶ out/<name>.feedback.txt   (repair_prompt)
```

## Run it

```sh
cd examples/llm_feedback
moon run cmd
```

```
[ok]       01_bar_fenced  →  out/01_bar_fenced.svg
[ok]       02_line_plain  →  out/02_line_plain.svg
[rejected] 03_broken_json  →  out/03_broken_json.feedback.txt
           JSON 解析失败: Invalid character ']' at line 7, column 4
[rejected] 04_data_url  →  out/04_data_url.feedback.txt
           data.url 暂不支持
[rejected] 05_unsupported  →  out/05_unsupported.feedback.txt
           params 暂不支持
[ok]       06_fixed_after_04  →  out/06_fixed_after_04.svg
3 rendered, 3 sent back for correction
```

| Recorded reply | What it is | Result |
| --- | --- | --- |
| `01_bar_fenced.txt` | prose around a ```` ```json ```` block | SVG |
| `02_line_plain.txt` | bare JSON | SVG |
| `03_broken_json.txt` | a trailing comma | prompt: JSON syntax error with line and column |
| `04_data_url.txt` | `data.url` (models love it) | prompt: put the data in `data.values` |
| `05_unsupported.txt` | `params` with a hover condition | prompt: the feature is not available |
| `06_fixed_after_04.txt` | the second reply, after the prompt for `04` | SVG, the loop is closed |

The three SVG files are byte-identical to what vega-lite 5.23.0 + vega 5.33.1 draw for the same specifications
(ignoring accessibility attributes).

## The prompt

`out/04_data_url.feedback.txt`:

```
你上一次给出的 Vega-Lite 规格无法渲染。
出错位置（JSON 路径）：data.url
原因：暂不支持
建议：本渲染器不读取外部文件：请把数据直接写成 data.values 数组。
请只修改这一处，其余部分保持不变，并且只返回修正后的完整 JSON。
```

(In English: *Your last Vega-Lite specification could not be rendered. Location (JSON path): `data.url`. Reason: not supported.
Suggestion: this renderer does not read external files, put the data in `data.values`. Change only this and return the complete
corrected JSON.*) A syntax error has no path, so the prompt says it cannot be located and quotes the line and column.

## The code

* [`feedback/feedback.mbt`](feedback/feedback.mbt), with tests in `feedback_test.mbt`:
  * `extract_json` takes the body of the first ``` fence, else everything from the first `{` to the last `}`;
  * `split_error` splits an error message into the JSON path and the reason (`path reason`, `path: reason`, or no path);
  * `repair_prompt` builds the prompt, with a suggestion for the common kinds of error.
* [`cmd/main.mbt`](cmd/main.mbt) reads `data/`, renders and writes `out/`.

Test the logic with `moon test -p sayoi7799/llm_feedback/feedback`. The module uses the library from the checkout through
`moon.work`, like [`examples/hello`](../hello).

A note on the code: the replies are listed in name order by a small hand-written sort. With the toolchain this was written
with (`moon 0.1.20261016`), `String::compare` orders by length before content, which would put `04_data_url` before `01_bar_fenced`.

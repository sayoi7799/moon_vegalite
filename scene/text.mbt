// Text measurement as vega-scenegraph does it when no canvas is available:
// widths are estimated as `~~(0.8 * length * fontSize)` (UTF-16 code units).

///|
pub fn font_size(item : Item) -> Double {
  match item.get("fontSize") {
    Null | Undef => 11.0
    v => {
      let x = v.to_number()
      if x != 0.0 && !x.is_nan() {
        x
      } else {
        0.0
      }
    }
  }
}

///|
pub fn line_height(item : Item) -> Double {
  match item.opt_num("lineHeight") {
    Some(h) => h
    None => font_size(item) + 2.0
  }
}

///|
fn estimate_width(text : String, font_height : Double) -> Double {
  @util.js_to_int32(0.8 * text.length().to_double() * font_height).to_double()
}

///|
fn text_limit(item : Item) -> Double {
  match item.get("limit") {
    Null | Undef => 0.0
    v => v.to_number()
  }
}

///|
/// vega `truncate`: shorten `text` with an ellipsis so its estimated width
/// stays below the item's `limit`.
fn truncate_text(item : Item, text : String) -> String {
  let fs = font_size(item)
  let width = fn(s : String) { estimate_width(s, fs) }
  let mut limit = text_limit(item)
  if width(text) < limit {
    return text
  }
  let ellipsis = match item.get("ellipsis") {
    v if v.truthy() => v.to_js_string()
    _ => "\u{2026}"
  }
  let rtl = match item.str("dir") {
    Some("rtl") => true
    _ => false
  }
  let mut lo = 0
  let mut hi = text.length()
  limit = limit - width(ellipsis)
  if rtl {
    while lo < hi {
      let mid = (lo + hi) >> 1
      if width(text.unsafe_substring(start=mid, end=text.length())) > limit {
        lo = mid + 1
      } else {
        hi = mid
      }
    }
    ellipsis + text.unsafe_substring(start=lo, end=text.length())
  } else {
    while lo < hi {
      let mid = 1 + ((lo + hi) >> 1)
      if width(text.unsafe_substring(start=0, end=mid)) < limit {
        lo = mid
      } else {
        hi = mid - 1
      }
    }
    text.unsafe_substring(start=0, end=lo) + ellipsis
  }
}

///|
/// vega `textValue(item, line)`: trimmed text, truncated to `limit`.
pub fn text_value(item : Item, line : @value.Value) -> String {
  let text = match line {
    Null | Undef => ""
    v => @value.trim_js(v.to_js_string())
  }
  if text_limit(item) > 0.0 && text.length() > 0 {
    truncate_text(item, text)
  } else {
    text
  }
}

///|
/// The text content as one value or several lines (vega `textLines`).
pub enum TextLines {
  Single(@value.Value)
  Lines(Array[@value.Value])
}

///|
pub fn text_lines(item : Item) -> TextLines {
  let text = item.get("text")
  let lb = item.get("lineBreak")
  let split : @value.Value = if lb.truthy() &&
    text.truthy() &&
    !(text is Arr(_)) {
    let parts = text
      .to_js_string()
      .split(lb.to_js_string())
      .map(fn(s) { @value.Value::Str(s.to_owned()) })
      .collect()
    Arr(parts)
  } else {
    text
  }
  match split {
    Arr(items) =>
      if items.length() > 1 {
        Lines(items)
      } else if items.length() == 1 {
        Single(items[0])
      } else {
        Single(Undef)
      }
    other => Single(other)
  }
}

///|
/// Width of a single line, as `textMetrics.width` (estimate).
pub fn text_width(item : Item, line : @value.Value) -> Double {
  estimate_width(text_value(item, line), font_size(item))
}

///|
/// vega `offset(item)`: baseline correction in pixels.
pub fn baseline_offset(item : Item) -> Double {
  let h = font_size(item)
  let r = match item.str("baseline") {
    Some("top") => 0.79 * h
    Some("middle") => 0.3 * h
    Some("bottom") => -0.21 * h
    Some("line-top") => 0.29 * h + 0.5 * line_height(item)
    Some("line-bottom") => 0.29 * h - 0.5 * line_height(item)
    _ => 0.0
  }
  @util.js_round(r)
}

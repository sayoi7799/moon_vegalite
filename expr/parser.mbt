// A parser for the subset of the Vega expression language supported by this
// library (see the README): literals, `datum` member access, JavaScript
// operators, the conditional operator and a fixed set of built-in functions.
// Everything else (signals, scale functions, regular expressions, object
// literals, ...) is rejected with an error that names the construct.

///|
pub(all) suberror ExprError {
  ExprError(String)
}

///|
pub(all) enum Expr {
  Lit(@value.Value)
  Ident(String)
  /// `object[property]` / `object.property`
  Member(Expr, Expr)
  Call(String, Array[Expr])
  Unary(String, Expr)
  Binary(String, Expr, Expr)
  /// `&&` and `||`, which return one of their operands
  Logical(String, Expr, Expr)
  Cond(Expr, Expr, Expr)
}

// ---- lexer ----

///|
priv enum Tok {
  Num(Double)
  Str(String)
  Id(String)
  Punct(String)
  End
}

///|
fn is_id_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == '$'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn hex_val(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 87
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 55
  } else {
    -1
  }
}

///|
let puncts : Array[String] = [
  ">>>", "===", "!==", "<<", ">>", "<=", ">=", "==", "!=", "&&", "||", "(", ")",
  "[", "]", ",", ".", "?", ":", "+", "-", "*", "/", "%", "!", "~", "<", ">", "&",
  "|", "^",
]

///|
fn tokenize(src : String) -> Array[Tok] raise ExprError {
  let cs = src.to_array()
  let n = cs.length()
  let out : Array[Tok] = []
  let mut i = 0
  while i < n {
    let c = cs[i]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      i = i + 1
    } else if is_digit(c) || (c == '.' && i + 1 < n && is_digit(cs[i + 1])) {
      let start = i
      if c == '0' && i + 1 < n && (cs[i + 1] == 'x' || cs[i + 1] == 'X') {
        i = i + 2
        let mut v = 0.0
        let hs = i
        while i < n && hex_val(cs[i]) >= 0 {
          v = v * 16.0 + hex_val(cs[i]).to_double()
          i = i + 1
        }
        if i == hs {
          raise ExprError(
            "Expression parse error: invalid hex literal in " + src,
          )
        }
        out.push(Num(v))
        continue
      }
      while i < n && is_digit(cs[i]) {
        i = i + 1
      }
      if i < n && cs[i] == '.' {
        i = i + 1
        while i < n && is_digit(cs[i]) {
          i = i + 1
        }
      }
      if i < n && (cs[i] == 'e' || cs[i] == 'E') {
        let save = i
        i = i + 1
        if i < n && (cs[i] == '+' || cs[i] == '-') {
          i = i + 1
        }
        let es = i
        while i < n && is_digit(cs[i]) {
          i = i + 1
        }
        if i == es {
          i = save
          raise ExprError("Expression parse error: malformed number in " + src)
        }
      }
      let mut text = String::from_array(cs[start:i])
      if text.has_prefix(".") {
        text = "0" + text
      }
      text = text.replace(old=".e", new=".0e").replace(old=".E", new=".0E")
      if text.has_suffix(".") {
        text = text + "0"
      }
      let v : Double = @string.from_str(text) catch {
        _ => raise ExprError("Expression parse error: malformed number " + text)
      }
      out.push(Num(v))
    } else if c == '"' || c == '\'' {
      let quote = c
      i = i + 1
      let sb = StringBuilder()
      let mut closed = false
      while i < n {
        let d = cs[i]
        if d == quote {
          closed = true
          i = i + 1
          break
        }
        if d == '\\' && i + 1 < n {
          let e = cs[i + 1]
          i = i + 2
          match e {
            'n' => sb.write_char('\n')
            't' => sb.write_char('\t')
            'r' => sb.write_char('\r')
            'b' => sb.write_char('\u{8}')
            'f' => sb.write_char('\u{c}')
            'v' => sb.write_char('\u{b}')
            '0' => sb.write_char('\u{0}')
            'x' =>
              if i + 1 < n && hex_val(cs[i]) >= 0 && hex_val(cs[i + 1]) >= 0 {
                sb.write_char(
                  (hex_val(cs[i]) * 16 + hex_val(cs[i + 1])).unsafe_to_char(),
                )
                i = i + 2
              } else {
                raise ExprError("Expression parse error: bad escape in " + src)
              }
            'u' => {
              let mut code = 0
              let mut cnt = 0
              if i < n && cs[i] == '{' {
                i = i + 1
                while i < n && cs[i] != '}' && hex_val(cs[i]) >= 0 {
                  code = code * 16 + hex_val(cs[i])
                  i = i + 1
                  cnt = cnt + 1
                }
                if i < n && cs[i] == '}' {
                  i = i + 1
                }
              } else {
                while cnt < 4 && i < n && hex_val(cs[i]) >= 0 {
                  code = code * 16 + hex_val(cs[i])
                  i = i + 1
                  cnt = cnt + 1
                }
              }
              if cnt == 0 {
                raise ExprError(
                  "Expression parse error: bad unicode escape in " + src,
                )
              }
              sb.write_char(code.unsafe_to_char())
            }
            other => sb.write_char(other)
          }
        } else {
          sb.write_char(d)
          i = i + 1
        }
      }
      if !closed {
        raise ExprError("Expression parse error: unterminated string in " + src)
      }
      out.push(Str(sb.to_string()))
    } else if is_id_start(c) {
      let start = i
      while i < n && (is_id_start(cs[i]) || is_digit(cs[i])) {
        i = i + 1
      }
      out.push(Id(String::from_array(cs[start:i])))
    } else {
      let mut matched = false
      for p in puncts {
        let pc = p.to_array()
        if i + pc.length() <= n {
          let mut ok = true
          for k in 0..<pc.length() {
            if cs[i + k] != pc[k] {
              ok = false
              break
            }
          }
          if ok {
            out.push(Punct(p))
            i = i + pc.length()
            matched = true
            break
          }
        }
      }
      if !matched {
        raise ExprError(
          "Expression parse error: unexpected character '" +
          c.to_string() +
          "' in " +
          src,
        )
      }
    }
  }
  out.push(End)
  out
}

// ---- parser ----

///|
priv struct Parser {
  toks : Array[Tok]
  mut pos : Int32
  src : String
}

///|
fn Parser::peek(self : Parser) -> Tok {
  self.toks[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Unit {
  if self.pos < self.toks.length() - 1 {
    self.pos = self.pos + 1
  }
}

///|
fn Parser::is_punct(self : Parser, p : String) -> Bool {
  match self.peek() {
    Punct(q) => q == p
    _ => false
  }
}

///|
fn Parser::expect(self : Parser, p : String) -> Unit raise ExprError {
  if self.is_punct(p) {
    self.advance()
  } else {
    raise ExprError(
      "Expression parse error: expected '" + p + "' in " + self.src,
    )
  }
}

///|
fn precedence(op : String) -> Int32 {
  match op {
    "||" => 1
    "&&" => 2
    "|" => 3
    "^" => 4
    "&" => 5
    "==" | "!=" | "===" | "!==" => 6
    "<" | ">" | "<=" | ">=" => 7
    "<<" | ">>" | ">>>" => 8
    "+" | "-" => 9
    "*" | "/" | "%" => 10
    _ => 0
  }
}

///|
fn Parser::parse_conditional(self : Parser) -> Expr raise ExprError {
  let cond = self.parse_binary(1)
  if self.is_punct("?") {
    self.advance()
    let a = self.parse_conditional()
    self.expect(":")
    let b = self.parse_conditional()
    Cond(cond, a, b)
  } else {
    cond
  }
}

///|
fn Parser::parse_binary(
  self : Parser,
  min_prec : Int32,
) -> Expr raise ExprError {
  let mut left = self.parse_unary()
  while true {
    let op = match self.peek() {
      Punct(p) => p
      _ => ""
    }
    let prec = precedence(op)
    if prec == 0 || prec < min_prec {
      break
    }
    self.advance()
    let right = self.parse_binary(prec + 1)
    left = if op == "&&" || op == "||" {
      Logical(op, left, right)
    } else {
      Binary(op, left, right)
    }
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise ExprError {
  match self.peek() {
    Punct("+") | Punct("-") | Punct("!") | Punct("~") as t => {
      let op = match t {
        Punct(p) => p
        _ => ""
      }
      self.advance()
      Unary(op, self.parse_unary())
    }
    _ => self.parse_postfix()
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> Expr raise ExprError {
  let mut e = self.parse_primary()
  while true {
    if self.is_punct(".") {
      self.advance()
      match self.peek() {
        Id(name) => {
          self.advance()
          e = Member(e, Lit(Str(name)))
        }
        _ =>
          raise ExprError(
            "Expression parse error: expected a property name in " + self.src,
          )
      }
    } else if self.is_punct("[") {
      self.advance()
      let idx = self.parse_conditional()
      self.expect("]")
      e = Member(e, idx)
    } else if self.is_punct("(") {
      let name = match e {
        Ident(n) => n
        _ =>
          raise ExprError(
            "Expression parse error: only named functions can be called in " +
            self.src,
          )
      }
      self.advance()
      let args : Array[Expr] = []
      if !self.is_punct(")") {
        args.push(self.parse_conditional())
        while self.is_punct(",") {
          self.advance()
          args.push(self.parse_conditional())
        }
      }
      self.expect(")")
      e = Call(name, args)
    } else {
      break
    }
  }
  e
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise ExprError {
  match self.peek() {
    Num(v) => {
      self.advance()
      Lit(Num(v))
    }
    Str(s) => {
      self.advance()
      Lit(Str(s))
    }
    Id(name) => {
      self.advance()
      match name {
        "true" => Lit(Bool(true))
        "false" => Lit(Bool(false))
        "null" => Lit(Null)
        _ => Ident(name)
      }
    }
    Punct("(") => {
      self.advance()
      let e = self.parse_conditional()
      self.expect(")")
      e
    }
    Punct("[") =>
      raise ExprError(
        "Expression parse error: array literals are not supported: " + self.src,
      )
    Punct(p) =>
      raise ExprError(
        "Expression parse error: unexpected '" + p + "' in " + self.src,
      )
    End =>
      raise ExprError(
        "Expression parse error: unexpected end of expression: " + self.src,
      )
  }
}

// ---- semantic checks ----

///|
let constants : Array[String] = [
  "NaN", "E", "LN2", "LN10", "LOG2E", "LOG10E", "PI", "SQRT1_2", "SQRT2", "MIN_VALUE",
  "MAX_VALUE",
]

///|
/// (min, max) argument counts of the supported functions; max < 0 means variadic.
fn function_arity(name : String) -> (Int32, Int32)? {
  match name {
    "isNaN"
    | "isFinite"
    | "abs"
    | "acos"
    | "asin"
    | "atan"
    | "ceil"
    | "cos"
    | "exp"
    | "floor"
    | "log"
    | "round"
    | "sin"
    | "sqrt"
    | "tan" => Some((1, 1))
    "atan2" | "pow" => Some((2, 2))
    "max" | "min" | "hypot" => Some((0, -1))
    "clamp" => Some((3, 3))
    "if" => Some((3, 3))
    "utc" => Some((1, 7))
    "datetime" => Some((1, 7))
    "date"
    | "day"
    | "year"
    | "month"
    | "hours"
    | "minutes"
    | "seconds"
    | "milliseconds"
    | "time"
    | "utcdate"
    | "utcday"
    | "utcyear"
    | "utcmonth"
    | "utchours"
    | "utcminutes"
    | "utcseconds"
    | "utcmilliseconds" => Some((1, 1))
    "length" | "upper" | "lower" | "trim" => Some((1, 1))
    "substring" | "slice" => Some((2, 3))
    "indexof" | "lastindexof" => Some((2, 2))
    "replace" => Some((3, 3))
    "isValid"
    | "isNumber"
    | "isString"
    | "isBoolean"
    | "isArray"
    | "toNumber"
    | "toString"
    | "toBoolean"
    | "toDate" => Some((1, 1))
    "format" | "timeFormat" | "utcFormat" => Some((2, 2))
    _ => None
  }
}

///|
fn check(e : Expr, src : String) -> Unit raise ExprError {
  match e {
    Lit(_) => ()
    Ident(name) =>
      if name != "datum" && !constants.contains(name) {
        raise ExprError(
          "Expression error: unsupported identifier '" +
          name +
          "' in " +
          src +
          " (only datum and the standard constants are available)",
        )
      }
    Member(o, p) => {
      check(o, src)
      check(p, src)
    }
    Call(name, args) => {
      match function_arity(name) {
        None =>
          raise ExprError(
            "Expression error: unsupported function '" + name + "' in " + src,
          )
        Some((lo, hi)) =>
          if args.length() < lo || (hi >= 0 && args.length() > hi) {
            raise ExprError(
              "Expression error: wrong number of arguments to " +
              name +
              " in " +
              src,
            )
          }
      }
      for a in args {
        check(a, src)
      }
    }
    Unary(_, a) => check(a, src)
    Binary(_, a, b) | Logical(_, a, b) => {
      check(a, src)
      check(b, src)
    }
    Cond(a, b, c) => {
      check(a, src)
      check(b, src)
      check(c, src)
    }
  }
}

///|
/// Parse and validate an expression string.
pub fn parse_expr(src : String) -> Expr raise ExprError {
  let toks = tokenize(src)
  let p : Parser = { toks, pos: 0, src, }
  let e = p.parse_conditional()
  match p.peek() {
    End => ()
    _ =>
      raise ExprError(
        "Expression parse error: unexpected trailing input in " + src,
      )
  }
  check(e, src)
  e
}

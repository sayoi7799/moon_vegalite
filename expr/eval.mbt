// Evaluation of parsed expressions with JavaScript semantics.

///|
fn prim(v : @value.Value) -> @value.Value {
  match v {
    Arr(_) | Obj(_) => Str(v.to_js_string())
    other => other
  }
}

///|
fn is_str(v : @value.Value) -> Bool {
  v is Str(_)
}

///|
/// The `+` operator.
fn js_add(a0 : @value.Value, b0 : @value.Value) -> @value.Value {
  let a = prim(a0)
  let b = prim(b0)
  if is_str(a) || is_str(b) {
    Str(a.to_js_string() + b.to_js_string())
  } else {
    Num(a.to_number() + b.to_number())
  }
}

///|
/// Abstract relational comparison `a < b` (false when either side is NaN).
pub fn js_less(a0 : @value.Value, b0 : @value.Value) -> Bool {
  let a = prim(a0)
  let b = prim(b0)
  match (a, b) {
    (Str(x), Str(y)) => x.lexical_compare(y) < 0
    _ => a.to_number() < b.to_number()
  }
}

///|
fn js_less_eq(a : @value.Value, b : @value.Value) -> Bool {
  let x = prim(a)
  let y = prim(b)
  match (x, y) {
    (Str(p), Str(q)) => p.lexical_compare(q) <= 0
    _ => x.to_number() <= y.to_number()
  }
}

///|
fn is_nullish(v : @value.Value) -> Bool {
  v is Null || v is Undef
}

///|
/// `a == b`.
fn js_loose_eq(a : @value.Value, b : @value.Value) -> Bool {
  if is_nullish(a) || is_nullish(b) {
    return is_nullish(a) && is_nullish(b)
  }
  match (a, b) {
    (Num(x), Num(y)) => x == y
    (Str(x), Str(y)) => x == y
    (Bool(x), Bool(y)) => x == y
    (Arr(_), Arr(_)) | (Obj(_), Obj(_)) => false
    (Arr(_), _) | (Obj(_), _) => js_loose_eq(prim(a), b)
    (_, Arr(_)) | (_, Obj(_)) => js_loose_eq(a, prim(b))
    _ => a.to_number() == b.to_number()
  }
}

///|
/// `a === b`.
fn js_strict_eq(a : @value.Value, b : @value.Value) -> Bool {
  match (a, b) {
    (Undef, Undef) | (Null, Null) => true
    (Num(x), Num(y)) => x == y
    (Str(x), Str(y)) => x == y
    (Bool(x), Bool(y)) => x == y
    _ => false
  }
}

///|
fn to_i32(v : @value.Value) -> Int32 {
  @util.js_to_int32(v.to_number())
}

///|
fn str_len(s : String) -> Int32 {
  s.length()
}

///|
/// ToIntegerOrInfinity for `substring` / `slice` style arguments.
fn to_index(v : @value.Value, default : Double) -> Double {
  match v {
    Undef => default
    other => {
      let x = other.to_number()
      if x.is_nan() {
        0.0
      } else {
        x.trunc()
      }
    }
  }
}

///|
fn clamp_index(x : Double, len : Int32) -> Int32 {
  if x < 0.0 {
    0
  } else if x > len.to_double() {
    len
  } else {
    x.to_int()
  }
}

///|
/// `new Date(value)` for a single argument, as epoch milliseconds.
fn date_of(v : @value.Value) -> Double {
  match v {
    Undef => @double.not_a_number
    Null => 0.0
    Num(x) =>
      if x.is_nan() || x.abs() > 8.64e15 {
        @double.not_a_number
      } else {
        x.trunc()
      }
    Str(s) => @value.parse_date(s)
    Bool(b) => if b { 1.0 } else { 0.0 }
    _ => @double.not_a_number
  }
}

///|
fn date_field(
  args : Array[@value.Value],
  pick : (@time.DateParts) -> Int32,
) -> @value.Value {
  let t = date_of(args[0])
  if t.is_nan() {
    Num(t)
  } else {
    Num(pick(@time.utc_parts(t)).to_double())
  }
}

///|
fn arg_or(args : Array[@value.Value], i : Int32, default : Double) -> Double {
  if i < args.length() {
    args[i].to_number()
  } else {
    default
  }
}

///|
fn math1(args : Array[@value.Value], f : (Double) -> Double) -> @value.Value {
  Num(f(args[0].to_number()))
}

///|
fn call_function(
  name : String,
  args : Array[@value.Value],
) -> @value.Value raise ExprError {
  match name {
    "isNaN" =>
      Bool(
        match args[0] {
          Num(x) => x.is_nan()
          _ => false
        },
      )
    "isFinite" =>
      Bool(
        match args[0] {
          Num(x) => !x.is_nan() && !x.is_inf()
          _ => false
        },
      )
    "abs" => math1(args, fn(x) { x.abs() })
    "acos" => math1(args, @math.acos)
    "asin" => math1(args, @math.asin)
    "atan" => math1(args, @math.atan)
    "atan2" => Num(@math.atan2(args[0].to_number(), args[1].to_number()))
    "ceil" => math1(args, fn(x) { x.ceil() })
    "cos" => math1(args, @math.cos)
    "exp" =>
      math1(args, fn(x) {
        if x == 1.0 {
          2.718281828459045
        } else {
          @math.exp(x)
        }
      })
    "floor" => math1(args, fn(x) { x.floor() })
    "log" => math1(args, @util.js_log)
    "round" => math1(args, @util.js_round)
    "sin" => math1(args, @math.sin)
    "sqrt" => math1(args, fn(x) { x.sqrt() })
    "tan" => math1(args, @math.tan)
    "pow" => Num(@math.pow(args[0].to_number(), args[1].to_number()))
    "hypot" => {
      let mut acc = 0.0
      let mut inf = false
      let mut nan = false
      for a in args {
        let x = a.to_number()
        if x.is_inf() {
          inf = true
        } else if x.is_nan() {
          nan = true
        }
        acc = acc + x * x
      }
      Num(
        if inf {
          @double.infinity
        } else if nan {
          @double.not_a_number
        } else {
          acc.sqrt()
        },
      )
    }
    "max" => {
      let mut r = @double.neg_infinity
      for a in args {
        r = @util.js_max(r, a.to_number())
      }
      Num(r)
    }
    "min" => {
      let mut r = @double.infinity
      for a in args {
        r = @util.js_min(r, a.to_number())
      }
      Num(r)
    }
    "clamp" =>
      Num(
        @util.js_max(
          args[1].to_number(),
          @util.js_min(args[2].to_number(), args[0].to_number()),
        ),
      )
    // dates: local time is UTC
    "date" | "utcdate" => date_field(args, fn(p) { p.date })
    "day" | "utcday" => date_field(args, fn(p) { p.day })
    "year" | "utcyear" => date_field(args, fn(p) { p.year })
    "month" | "utcmonth" => date_field(args, fn(p) { p.month })
    "hours" | "utchours" => date_field(args, fn(p) { p.hours })
    "minutes" | "utcminutes" => date_field(args, fn(p) { p.minutes })
    "seconds" | "utcseconds" => date_field(args, fn(p) { p.seconds })
    "milliseconds" | "utcmilliseconds" => date_field(args, fn(p) { p.millis })
    "time" => Num(date_of(args[0]))
    "datetime" =>
      if args.length() == 1 {
        Num(date_of(args[0]))
      } else {
        Num(
          @time.utc_ms(
            arg_or(args, 0, @double.not_a_number),
            arg_or(args, 1, 0.0),
            arg_or(args, 2, 1.0),
            arg_or(args, 3, 0.0),
            arg_or(args, 4, 0.0),
            arg_or(args, 5, 0.0),
            arg_or(args, 6, 0.0),
          ),
        )
      }
    "utc" =>
      Num(
        @time.utc_ms(
          arg_or(args, 0, @double.not_a_number),
          arg_or(args, 1, 0.0),
          arg_or(args, 2, 1.0),
          arg_or(args, 3, 0.0),
          arg_or(args, 4, 0.0),
          arg_or(args, 5, 0.0),
          arg_or(args, 6, 0.0),
        ),
      )
    // strings and sequences
    "length" =>
      match args[0] {
        Str(s) => Num(str_len(s).to_double())
        Arr(a) => Num(a.length().to_double())
        _ =>
          raise ExprError("Expression error: length() needs a string or array")
      }
    "upper" => Str(args[0].to_js_string().to_upper())
    "lower" => Str(args[0].to_js_string().to_lower())
    "trim" => Str(@value.trim_js(args[0].to_js_string()))
    "substring" => {
      let s = args[0].to_js_string()
      let len = str_len(s)
      let a = clamp_index(to_index(args[1], 0.0), len)
      let b = clamp_index(
        if args.length() > 2 {
          to_index(args[2], len.to_double())
        } else {
          len.to_double()
        },
        len,
      )
      let lo = if a < b { a } else { b }
      let hi = if a < b { b } else { a }
      Str(s.unsafe_substring(start=lo, end=hi))
    }
    "slice" => {
      let rel = fn(x : Double, len : Int32) {
        if x < 0.0 {
          let r = len.to_double() + x
          if r < 0.0 {
            0
          } else {
            r.to_int()
          }
        } else if x > len.to_double() {
          len
        } else {
          x.to_int()
        }
      }
      match args[0] {
        Arr(items) => {
          let a = rel(to_index(args[1], 0.0), items.length())
          let b = rel(
            if args.length() > 2 {
              to_index(args[2], items.length().to_double())
            } else {
              items.length().to_double()
            },
            items.length(),
          )
          Arr(if a < b { items[a:b].to_owned() } else { [] })
        }
        other => {
          let s = other.to_js_string()
          let len = str_len(s)
          let a = rel(to_index(args[1], 0.0), len)
          let b = rel(
            if args.length() > 2 {
              to_index(args[2], len.to_double())
            } else {
              len.to_double()
            },
            len,
          )
          Str(if a < b { s.unsafe_substring(start=a, end=b) } else { "" })
        }
      }
    }
    "indexof" => {
      let s = args[0].to_js_string()
      let sub = args[1].to_js_string()
      Num(
        match s.find(sub) {
          Some(i) => i.to_double()
          None => -1.0
        },
      )
    }
    "lastindexof" => {
      let s = args[0].to_js_string()
      let sub = args[1].to_js_string()
      Num(
        match s.rev_find(sub) {
          Some(i) => i.to_double()
          None => -1.0
        },
      )
    }
    "replace" => {
      let s = args[0].to_js_string()
      let pat = args[1].to_js_string()
      let rep = args[2].to_js_string()
      match s.find(pat) {
        Some(i) =>
          Str(
            s.unsafe_substring(start=0, end=i) +
            rep +
            s.unsafe_substring(start=i + pat.length(), end=s.length()),
          )
        None => Str(s)
      }
    }
    // type checks and conversions
    "isValid" => Bool(args[0].is_valid())
    "isNumber" => Bool(args[0] is Num(_))
    "isString" => Bool(args[0] is Str(_))
    "isBoolean" => Bool(args[0] is Bool(_))
    "isArray" => Bool(args[0] is Arr(_))
    "toNumber" => args[0].coerce_number()
    "toString" => args[0].coerce_string()
    "toBoolean" => args[0].coerce_boolean()
    "toDate" => args[0].coerce_date()
    "format" =>
      match args[0] {
        Null => Str("null")
        v => {
          let f = @format.format(args[1].to_js_string()) catch {
            @format.FormatError(msg) =>
              raise ExprError("Expression error: " + msg)
          }
          Str(f(v.to_number()))
        }
      }
    "timeFormat" | "utcFormat" =>
      match args[0] {
        Null => Str("null")
        v => Str(@time.utc_format(args[1].to_js_string())(v.to_number()))
      }
    _ =>
      raise ExprError("Expression error: unsupported function '" + name + "'")
  }
}

///|
fn constant_value(name : String) -> @value.Value? {
  match name {
    "NaN" => Some(Num(@double.not_a_number))
    "E" => Some(Num(2.718281828459045))
    "LN2" => Some(Num(0.6931471805599453))
    "LN10" => Some(Num(2.302585092994046))
    "LOG2E" => Some(Num(1.4426950408889634))
    "LOG10E" => Some(Num(0.4342944819032518))
    "PI" => Some(Num(3.141592653589793))
    "SQRT1_2" => Some(Num(0.7071067811865476))
    "SQRT2" => Some(Num(1.4142135623730951))
    "MIN_VALUE" => Some(Num(5.0e-324))
    "MAX_VALUE" => Some(Num(1.7976931348623157e308))
    _ => None
  }
}

///|
fn get_member(
  obj : @value.Value,
  key : @value.Value,
) -> @value.Value raise ExprError {
  match obj {
    Null | Undef =>
      raise ExprError(
        "Expression error: cannot read properties of " + obj.to_js_string(),
      )
    Obj(m) =>
      match m.get(key.to_js_string()) {
        Some(v) => v
        None => Undef
      }
    Arr(items) =>
      match key {
        Str("length") => Num(items.length().to_double())
        k => {
          let i = k.to_number()
          if i >= 0.0 && i == i.trunc() && i < items.length().to_double() {
            items[i.to_int()]
          } else {
            Undef
          }
        }
      }
    Str(s) =>
      match key {
        Str("length") => Num(str_len(s).to_double())
        k => {
          let i = k.to_number()
          if i >= 0.0 && i == i.trunc() && i < str_len(s).to_double() {
            Str(s.unsafe_substring(start=i.to_int(), end=i.to_int() + 1))
          } else {
            Undef
          }
        }
      }
    _ => Undef
  }
}

///|
fn num(x : Double) -> @value.Value {
  Num(x)
}

///|
fn eval_binary(op : String, a : @value.Value, b : @value.Value) -> @value.Value {
  match op {
    "+" => js_add(a, b)
    "-" => num(a.to_number() - b.to_number())
    "*" => num(a.to_number() * b.to_number())
    "/" => num(a.to_number() / b.to_number())
    "%" => num(a.to_number().mod(b.to_number()))
    "==" => Bool(js_loose_eq(a, b))
    "!=" => Bool(!js_loose_eq(a, b))
    "===" => Bool(js_strict_eq(a, b))
    "!==" => Bool(!js_strict_eq(a, b))
    "<" => Bool(js_less(a, b))
    ">" => Bool(js_less(b, a))
    "<=" => Bool(js_less_eq(a, b))
    ">=" => Bool(js_less_eq(b, a))
    "&" => num((to_i32(a) & to_i32(b)).to_double())
    "|" => num((to_i32(a) | to_i32(b)).to_double())
    "^" => num((to_i32(a) ^ to_i32(b)).to_double())
    "<<" => num((to_i32(a) << (to_i32(b) & 31)).to_double())
    ">>" => num((to_i32(a) >> (to_i32(b) & 31)).to_double())
    ">>>" =>
      num((to_i32(a).reinterpret_as_uint() >> (to_i32(b) & 31)).to_double())
    _ => Undef
  }
}

///|
/// Evaluate an expression against a row (`datum`).
pub fn eval_expr(
  e : Expr,
  datum : @value.Value,
) -> @value.Value raise ExprError {
  match e {
    Lit(v) => v
    Ident(name) =>
      if name == "datum" {
        datum
      } else {
        match constant_value(name) {
          Some(v) => v
          None =>
            raise ExprError(
              "Expression error: unknown identifier '" + name + "'",
            )
        }
      }
    Member(o, p) => get_member(eval_expr(o, datum), eval_expr(p, datum))
    Call(name, args) =>
      if name == "if" {
        if eval_expr(args[0], datum).truthy() {
          eval_expr(args[1], datum)
        } else {
          eval_expr(args[2], datum)
        }
      } else {
        let vals : Array[@value.Value] = []
        for a in args {
          vals.push(eval_expr(a, datum))
        }
        call_function(name, vals)
      }
    Unary(op, a) => {
      let v = eval_expr(a, datum)
      match op {
        "+" => num(v.to_number())
        "-" => num(-v.to_number())
        "!" => Bool(!v.truthy())
        _ => num((to_i32(v) ^ -1).to_double())
      }
    }
    Binary(op, a, b) =>
      eval_binary(op, eval_expr(a, datum), eval_expr(b, datum))
    Logical(op, a, b) => {
      let l = eval_expr(a, datum)
      if op == "&&" {
        if l.truthy() {
          eval_expr(b, datum)
        } else {
          l
        }
      } else if l.truthy() {
        l
      } else {
        eval_expr(b, datum)
      }
    }
    Cond(t, a, b) =>
      if eval_expr(t, datum).truthy() {
        eval_expr(a, datum)
      } else {
        eval_expr(b, datum)
      }
  }
}

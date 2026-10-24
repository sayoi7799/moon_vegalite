// The `sort` property of discrete position channels: the order of the band /
// point scale domain.

///|
fn first_appearance(
  rows : Array[Map[String, @value.Value]],
  field : String,
) -> Array[@value.Value] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[@value.Value] = []
  for r in rows {
    let v = @value.get_field(r, field)
    let k = @scale.value_key(v)
    if !seen.contains(k) {
      seen[k] = true
      out.push(v)
    }
  }
  out
}

///|
fn cmp_double(a : Double, b : Double) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Order `keys` by an aggregate of `field` over the rows of each key.
fn order_by_aggregate(
  pre : Array[Map[String, @value.Value]],
  key_field : String,
  op : String,
  field : String?,
  descending : Bool,
  keys : Array[@value.Value],
) -> Array[@value.Value] raise CompileError {
  let agg = @transform.aggregate(pre, [key_field], [
    { op, field: if op == "count" { None } else { field }, out: "__sort", },
  ]) catch {
    e => raise transform_err(e)
  }
  let value_of : Map[String, @value.Value] = Map([])
  for r in agg {
    value_of[@scale.value_key(@value.get_field(r, key_field))] = @value.get_field(
      r, "__sort",
    )
  }
  @transform.stable_sort(keys, fn(a, b) {
    let c = @value.compare_values(
      match value_of.get(@scale.value_key(a)) {
        Some(v) => v
        None => Null
      },
      match value_of.get(@scale.value_key(b)) {
        Some(v) => v
        None => Null
      },
    )
    if descending {
      -c
    } else {
      c
    }
  })
}

///|
/// The domain order requested by `sort`, or None for the default (ascending).
fn sort_domain(
  p : Pos,
  sort : @value.Value,
  pre : Array[Map[String, @value.Value]],
  data : Array[Map[String, @value.Value]],
  px : Pos?,
  py : Pos?,
) -> Array[@value.Value]? raise CompileError {
  let path = "encoding.sort"
  match sort {
    Null => Some(first_appearance(data, p.field))
    Str("ascending") => None
    Str("descending") => {
      let asc = sorted_unique(data, p.field)
      asc.rev_in_place()
      Some(asc)
    }
    Arr(order) => {
      let index : Map[String, Double] = Map([])
      for i in 0..<order.length() {
        index[@scale.value_key(order[i])] = i.to_double()
      }
      Some(
        @transform.stable_sort(first_appearance(data, p.field), fn(a, b) {
          let ia = match index.get(@scale.value_key(a)) {
            Some(v) => v
            None => order.length().to_double()
          }
          let ib = match index.get(@scale.value_key(b)) {
            Some(v) => v
            None => order.length().to_double()
          }
          cmp_double(ia, ib)
        }),
      )
    }
    Str(s) => {
      let desc = s.has_prefix("-")
      let target = if desc { s[1:].to_owned() } else { s }
      let other = match target {
        "x" => px
        "y" => py
        _ => raise nope(path + " " + s)
      }
      match other {
        Some({ def: { aggregate: Some(op), field, .. }, .. }) =>
          Some(
            order_by_aggregate(
              pre,
              p.field,
              op,
              field,
              desc,
              first_appearance(data, p.field),
            ),
          )
        _ => raise nope(path + " " + s)
      }
    }
    Obj(m) => {
      let op = match m.get("op") {
        Some(Str(o)) => o
        _ => raise nope(path + ".op")
      }
      let field = match m.get("field") {
        Some(Str(f)) => Some(f)
        _ => None
      }
      let desc = match m.get("order") {
        Some(Str("descending")) => true
        _ => false
      }
      Some(
        order_by_aggregate(
          pre,
          p.field,
          op,
          field,
          desc,
          first_appearance(data, p.field),
        ),
      )
    }
    _ => raise nope(path)
  }
}

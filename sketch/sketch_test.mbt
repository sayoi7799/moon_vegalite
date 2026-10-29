///|
test "shape_seed stays in the generator's range and depends on every index" {
  let seen : Map[Int32, Bool] = Map([])
  for base in [0, 1, 2, 42, -7, 2147483647] {
    for a in 0..<6 {
      for b in 0..<6 {
        let s = @sketch.shape_seed(base, [a, b])
        assert_true(s >= 1 && s <= 2147483646)
        seen[s] = true
      }
    }
  }
  // 6 * 36 inputs, all different
  assert_eq(seen.length(), 216)
  assert_eq(@sketch.shape_seed(5, [1, 2]), @sketch.shape_seed(5, [1, 2]))
  assert_true(@sketch.shape_seed(5, [1, 2]) != @sketch.shape_seed(5, [2, 1]))
  assert_true(@sketch.shape_seed(5, [1]) != @sketch.shape_seed(5, [1, 0]))
}

///|
test "shape_seed gives the same numbers on every target" {
  // computed independently with BigInt in JavaScript; they must not change between targets or versions
  inspect(@sketch.shape_seed(1, []), content="824515496")
  inspect(@sketch.shape_seed(1, [0, 0, 0]), content="927936172")
  inspect(@sketch.shape_seed(42, [3, 1, 4, 1, 5]), content="1874205454")
  inspect(@sketch.shape_seed(-7, [2]), content="258450101")
}

use "pony_test"

class \nodoc\ _TestBitSet is UnitTest
  fun name()
  : String =>
    "BitSet"

  fun apply(
    h: TestHelper)
  =>
    h.assert_eq[U128](BitSet.set(0, 0), 1)
    h.assert_eq[U128](BitSet.set(0, 1), 2)
    h.assert_eq[U128](BitSet.set(0, 128), 0)
    h.assert_eq[U128](BitSet.set(0, 127), (U128(1) << 127))
    h.assert_eq[U128](BitSet.set(1, 0), 1)
    h.assert_eq[U128](BitSet.unset(1, 0), 0)
    h.assert_eq[U128](BitSet.unset(1, 127), 1)
    h.assert_eq[U128](BitSet.unset(1, 128), 1)
    h.assert_eq[U128](BitSet.unset(2, 0), 2)
    h.assert_eq[U128](BitSet.unset(2, 1), 0)
    h.assert_eq[U128](BitSet.union(1, 1), 1)
    h.assert_eq[U128](BitSet.union(1, 2), 3)
    h.assert_eq[U128](BitSet.intersect(1, 1), 1)
    h.assert_eq[U128](BitSet.intersect(1, 0), 0)
    h.assert_eq[U128](BitSet.intersect(1, 3), 1)
    h.assert_eq[Bool](BitSet.is_set(0, 0), false)
    h.assert_eq[Bool](BitSet.is_set(1, 0), true)

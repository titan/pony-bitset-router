primitive BitSet
  fun set(
    self: U128 val,
    idx: U8 val)
  : U128 val =>
    if idx < 128 then
      self or (U128(1) << idx.u128())
    else
      self
    end

  fun unset(
    self: U128 val,
    idx: U8 val)
  : U128 val =>
    if idx < 128 then
      self and (not (U128(1) << idx.u128()))
    else
      self
    end

  fun is_set(
    self: U128 val,
    idx: U8 val)
  : Bool val =>
    if idx < 128 then
      (self and (U128(1) << idx.u128())) != 0
    else
      false
    end

  fun union(
    a: U128 val,
    b: U128 val)
  : U128 val =>
    a or b

  fun intersect(
    a: U128 val,
    b: U128 val)
  : U128 val =>
    a and b

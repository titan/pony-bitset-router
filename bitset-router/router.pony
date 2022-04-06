"""
# BitSet-Router Package

BitSet-Router matchs URL patterns with support for dynamic and wildcard
segments.

The router focus on speed by using bitset data structure, but limits only 128
routes. It supports 3 kinds of route segments:

- segments: these are of the format `/a/b`.

- params: these are of the format `/a/:b`.

- named wildcards: these are of the format `/a/*b`.

Unnamed wildcards and nest routes are not supported.

The difference between a "named wildcard" and a "param" is how the matching
rules apply. Given the router `/a/:b`, passing in `/a/foo/bar` will not match,
because `/bar` has no counterpart in the router.

If we define the route `/a/*b` and pass `/a/foo/bar`, we end up with a named
param "b" that contains the value "foo/bar". Wildcard routing rules are useful
when we dont' know which routes may follow.

```pony
use "bitset-router"

actor Main
  new create(env: Env) =>
    let router = Router

    router.add("/user/:user-id")
    router.add("/user/:user-id/post/:post-id")
    router.add("/profile")
    router.add("/file/*filepath")

    let router': val = consume router

    match router'.find("/user/pony")
    | (let index: USize val, let params: Array[(String val, String val)] val) =>
      for (key, value) in params.values() do
        env.out.print(key + ": " + value)
      end
    end

```
"""

use "collections"
use "itertools"

type _Segment is (
  Map[String val, U128 val] val, // static
  U128 val, // dynamic
  U128 val, // wildcard
  U128 val // terminate
)

type _Capture is (
  String val, // name
  USize val // index in url
)

type _Route is (
  USize val, // segment number
  U64 val, // rank
  Array[_Capture val] val, // captures: [_Capture]
  String val // wildcard name
)

class val Router
  let _segments: Array[_Segment] ref
  let _routes: Array[_Route val] ref

  new trn create()
  =>
    """
    Create a new instance of Router.
    """
    _segments = Array[_Segment]
    _routes = Array[_Route val]

  fun ref add(
    pattern: String val)
  : (USize val | String val) =>
    """
    Add new pattern to the router. If success then return the index of route in
    the router, or the error message.
    """
    if _routes.size() == 0x7F then
      return "A single router can not hold more than 128 routes."
    end

    match _Lexer(pattern)
    | (_LexFailed, let err: _LexError) =>
      match err
      | _LexErrorPlaceholderNameContainColonOrAsterisk =>
        return "Capture name cannot contain `:` or `*`."
      | _LexErrorPlaceholderNameEmpty =>
        return "Capture name cannot be empty."
      | _LexErrorStaticContainColonOrAsterisk =>
        return "Static pattern cannot contain `:` or `*`."
      | _LexErrorWildcardNameContainColonOrAsterisk =>
        return "Wildcard name cannot contain `:` or `*`."
      | _LexErrorWildcardNameEmpty =>
        return "Wildcard name cannot be empty."
      | _LexErrorWildcardShouldBeLastToken =>
        return "Wildcard pattern can only appear at end."
      | _LexErrorPatternMustStartWithSlash =>
        return "Pattern must start with slash."
      else
        return "Unknown error."
      end
    | (_LexDone, let tokens: Array[_Token val] val) =>
      if tokens.size() > 64 then
        return "A single router cannot hold more than 64 segments."
      end
      let index: USize val = _routes.size()
      var rank: U64 = 0
      var wildcard: String = ""
      let captures: Array[_Capture val] trn = recover trn Array[_Capture] end

      // Scan captures
      for (idx, token) in tokens.pairs() do
        rank = rank << 1
        match token
        | (_PlaceholderToken, let name: String val) =>
          captures.push((name, idx))
        | (_WildcardToken, let name: String val) =>
          wildcard = name
        else
          rank = rank or 1
        end
      end

      // check collision
      if _check_collision(tokens, wildcard, rank) then
        return "Pattern collision occurred."
      end

      // Extend segments if needed
      let segment_number = tokens.size()
      if segment_number > _segments.size() then
        (let wildcard_base: U128, let terminate_base: U128) =
          try
            let segment' = _segments(_segments.size() - 1)?
            (segment'._3, segment'._4)
          else
            (U128(0), U128(0))
          end
        repeat
          _segments.push((recover Map[String val, U128 val] end, U128(0), wildcard_base, terminate_base))
        until segment_number == _segments.size() end
      end

      // Set bitset
      for (token, (depth, segment)) in Iter[_Token](tokens.values()).zip[(USize, _Segment)](Iter[_Segment](_segments.values()).enum[USize]()) do
        match token
        | (_PlaceholderToken, _) =>
          try
            _segments(depth)? = (segment._1, BitSet.set(segment._2, index), segment._3, segment._4)
          end
        | (_WildcardToken, _) =>
          try
            _segments(depth)? = (segment._1, segment._2, BitSet.set(segment._3, index), segment._4)
          end
        | (_StaticToken, let static: String val) =>
          let bitset = segment._1.get_or_else(static, 0)
          let statics = recover iso segment._1.clone() end // statics
          statics(static) = BitSet.set(bitset, index)

          try
            _segments(depth)? = (consume statics, segment._2, segment._3, segment._4)
          end
        end
      end

      // Adjust bitsets for wildcard
      if wildcard.size() > 0 then
        let pos = tokens.size()
        for (depth, segment) in Iter[_Segment](_segments.values()).enum[USize]().skip(pos) do
          try
            _segments(depth)? = (segment._1, segment._2, BitSet.set(segment._3, index), segment._4)
          end
        end
      end

      // Set terminate flag
      for (depth, segment) in Iter[_Segment](_segments.values()).enum[USize]().skip(segment_number - 1) do
        try
          _segments(depth)? = (segment._1, segment._2, segment._3, BitSet.set(segment._4, index))
        end
      end

      _routes.push((segment_number, rank, consume captures, wildcard))

      index
    end

  fun find(
    path: String val)
  : ((USize val, Array[(String val, String val)] val) | None) =>
    """
    Match a router on the router. If matched, return the index of calling
    `insert` function and captured key-value parameters; if not then just return
    None.
    """
    try
      if path(0)? != '/' then
        return None
      end
    end
    let parts: Array[String val] val =
      try
        let parts' = path.split("/")
        parts'.shift()?
        consume parts'
      else
        recover Array[String val] end
      end
    var enabled: U128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    let captures: Array[(String val, String val)] iso = recover iso Array[(String val, String val)]() end

    for (part, segment) in Iter[String val](parts.values()).zip[_Segment](_segments.values()) do
      var e = segment._2 // dynamic
      e = BitSet.union(e, segment._1.get_or_else(part, e)) // static
      e = BitSet.union(e, segment._3) // wildcard
      enabled = BitSet.intersect(enabled, e)
    end

    if parts.size() > _segments.size() then
      // Parts length is greater than segments length, so check wildcard
      // patterns.
      try
        let last_wildcard = _segments(_segments.size() - 1)?._3 // wildcard
        enabled = BitSet.intersect(enabled, last_wildcard)
      end
    end

    if (parts.size() - 1) < _segments.size() then
      try
        let segment = _segments(parts.size() - 1)?
        enabled = BitSet.intersect(enabled, segment._4 /* terminate */)
      end
    end

    if enabled == 0 then
      return None
    end

    let hitted: Iter[(USize val, _Route val)] = Iter[_Route val](_routes.values())
      .enum[USize val]()
      .filter({(x: (USize val, _Route val)) =>
        let idx: USize val = x._1
        BitSet.is_set(enabled, idx)
      })

    try
      var h: (USize val, _Route val) = hitted.next()?
      for h' in hitted do
        if (h'._2._1 == h._2._1) // segment-number
          and (h'._2._2 > h._2._2) // rank
        then
          // Match as rank high as possible
          h = h'
        elseif h'._2._1 > h._2._1 // segment-number
        then
          // Match as deep as possible
          h = h'
        end
      end

      // Scan captures
      for (name, idx) in h._2._3.values() do
        try
          captures.push((name, parts(idx) ?))
        end
      end

      // Scan wildcard
      if h._2._4.size() > 0 then
        // wildcard is present
        try
          let part = parts(h._2._1 - 1) ?
          let offset = path.find(part) ?
          let value = path.substring(offset)
          captures.push((h._2._4, consume value))
        end
      end

      (h._1, consume captures)
    else
      None
    end

  fun ref _check_collision(
    tokens: Array[_Token val] val,
    wildcard: String val,
    rank: U64)
  : Bool =>
    var enabled: U128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    for (token, segment) in Iter[_Token val](tokens.values()).zip[_Segment](_segments.values()) do
      var e = segment._2 // dynamic
      e = BitSet.union(e, segment._3 /* wildcard */)
      match token
      | (_StaticToken, let static: String val) =>
        e = BitSet.union(e, segment._1.get_or_else(static, e))
      end
      enabled = BitSet.intersect(enabled, e)
    end

    let hitted: Iter[(USize val, _Route val)] =
      Iter[_Route val](_routes.values())
      .enum[USize val]()
      .filter({(x: (USize val, _Route val)) =>
        let idx: USize val = x._1
        BitSet.is_set(enabled, idx)
      })

    hitted.any({(x: (USize val, _Route val)) =>
      let same = (not (x._2._4.size() > 0)) xor (wildcard.size() > 0)
      same and (rank == x._2._2)
    })

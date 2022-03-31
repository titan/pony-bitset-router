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

    match router.find("/user/pony")
    | (let index: U8 val, let params: Array[(String val, String val)] val) =>
      for (key, value) in params.values() do
        env.out.print(key + ": " + value)
      end
    end

```
"""

use "collections"
use "itertools"

class _Segment
  let static: Map[String val, U128]
  var dynamic: U128
  var wildcard: U128
  var terminate: U128

  new create(
    static': Map[String val, U128] = Map[String val, U128],
    dynamic': U128 = 0,
    wildcard': U128 = 0,
    terminate': U128 = 0)
  =>
    static = static'
    dynamic = dynamic'
    wildcard = wildcard'
    terminate = terminate'

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

class Router
  let _segments: Array[_Segment ref] ref
  let _routes: Array[_Route val] ref

  new create()
  =>
    """
    Create a new instance of Router.
    """
    _segments = Array[_Segment ref]
    _routes = Array[_Route val]

  fun ref add(
    pattern: String val)
  : (U8 val | String val) =>
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
      let index: U8 val = _routes.size().u8()
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
            (segment'.wildcard, segment'.terminate)
          else
            (U128(0), U128(0))
          end
        repeat
          _segments.push(_Segment(where wildcard' = wildcard_base, terminate' = terminate_base))
        until segment_number == _segments.size() end
      end

      // Set bitset
      for (token, segment) in Iter[_Token](tokens.values()).zip[_Segment ref](_segments.values()) do
        match token
        | (_PlaceholderToken, _) =>
          segment.dynamic = BitSet.set(segment.dynamic, index)
        | (_WildcardToken, _) =>
          segment.wildcard = BitSet.set(segment.wildcard, index)
        | (_StaticToken, let static: String val) =>
          let bitset = segment.static.get_or_else(static, 0)
          segment.static.update(static, BitSet.set(bitset, index))
        end
      end

      // Adjust bitsets for wildcard
      if wildcard.size() > 0 then
        let pos = tokens.size()
        for segment in Iter[_Segment](_segments.values()).skip(pos) do
          segment.wildcard = BitSet.set(segment.wildcard, index)
        end
      end

      // Set terminate flag
      for segment in Iter[_Segment](_segments.values()).skip(segment_number - 1) do
          segment.terminate = BitSet.set(segment.terminate, index)
      end

      _routes.push((segment_number, rank, consume captures, wildcard))

      index
    end

  fun ref find(
    path: String val)
  : ((U8 val, Array[(String val, String val)] val) | None) =>
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

    for (part, segment) in Iter[String val](parts.values()).zip[_Segment ref](_segments.values()) do
      var e = segment.dynamic
      e = BitSet.union(e, segment.static.get_or_else(part, e))
      e = BitSet.union(e, segment.wildcard)
      enabled = BitSet.intersect(enabled, e)
    end

    if parts.size() > _segments.size() then
      // Parts length is greater than segments length, so check wildcard
      // patterns.
      try
        let last_wildcard = _segments(_segments.size() - 1)?.wildcard
        enabled = BitSet.intersect(enabled, last_wildcard)
      end
    end

    if (parts.size() - 1) < _segments.size() then
      try
        let segment = _segments(parts.size() - 1)?
        enabled = BitSet.intersect(enabled, segment.terminate)
      end
    end

    if enabled == 0 then
      return None
    end

    let hitted: Iter[(U8 val, _Route val)] = Iter[_Route val](_routes.values())
      .enum[U8 val]()
      .filter({(x: (U8 val, _Route val)) =>
        let idx: U8 val = x._1
        BitSet.is_set(enabled, idx)
      })

    try
      var h: (U8 val, _Route val) = hitted.next()?
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
    for (token, segment) in Iter[_Token val](tokens.values()).zip[_Segment ref](_segments.values()) do
      var e = segment.dynamic
      e = BitSet.union(e, segment.wildcard)
      match token
      | (_StaticToken, let static: String val) =>
        e = BitSet.union(e, segment.static.get_or_else(static, e))
      end
      enabled = BitSet.intersect(enabled, e)
    end

    let hitted: Iter[(U8 val, _Route val)] =
      Iter[_Route val](_routes.values())
      .enum[U8 val]()
      .filter({(x: (U8 val, _Route val)) =>
        let idx: U8 val = x._1
        BitSet.is_set(enabled, idx)
      })

    hitted.any({(x: (U8 val, _Route val)) =>
      let same = (not (x._2._4.size() > 0)) xor (wildcard.size() > 0)
      same and (rank == x._2._2)
    })

interface val _TokenType is (Equatable[_TokenType] & Stringable)

primitive _PlaceholderToken is _TokenType
  fun eq(
    o: _TokenType)
  : Bool =>
    o is this

  fun string()
  : String iso^ =>
    ":".clone()

primitive _StaticToken is _TokenType
  fun eq(
    o: _TokenType)
  : Bool =>
    o is this

  fun string()
  : String iso^ =>
    "".clone()

primitive _WildcardToken is _TokenType
  fun eq(
    o: _TokenType)
  : Bool =>
    o is this

  fun string()
  : String iso^ =>
    "*".clone()

type _Token is
  (
    ( _PlaceholderToken
    | _StaticToken
    | _WildcardToken
    ),
    String val
  )

primitive _InitState
primitive _PlaceholderState
primitive _StaticState
primitive _WildcardState

type _LexerState is
  ( _InitState
  | _PlaceholderState
  | _StaticState
  | _WildcardState
  )

interface val _LexErrorType is (Equatable[_LexErrorType] & Stringable)

primitive _LexErrorPlaceholderNameContainColonOrAsterisk is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorPlaceholderNameContainColonOrAsterisk".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorPlaceholderNameEmpty is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorPlaceholderNameEmpty".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorStaticContainColonOrAsterisk is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorStaticContainColonOrAsterisk".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorWildcardNameContainColonOrAsterisk is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorWildcardNameContainColonOrAsterisk".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorWildcardNameEmpty is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorWildcardNameEmpty".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorWildcardShouldBeLastToken is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorWildcardShouldBeLastToken".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

primitive _LexErrorPatternMustStartWithSlash is _LexErrorType
  fun string()
  : String iso^ =>
    "LexErrorPatternMustStartWithSlash".clone()

  fun eq(
    o: _LexErrorType)
  : Bool =>
    o is this

type _LexError is
  (
    ( _LexErrorPlaceholderNameContainColonOrAsterisk
    | _LexErrorPlaceholderNameEmpty
    | _LexErrorStaticContainColonOrAsterisk
    | _LexErrorWildcardNameContainColonOrAsterisk
    | _LexErrorWildcardNameEmpty
    | _LexErrorWildcardShouldBeLastToken
    | _LexErrorPatternMustStartWithSlash
    ) &
    _LexErrorType
  )

primitive _LexDone
primitive _LexFailed

type _LexResult is
  ( (_LexDone, Array[_Token val] val)
  | (_LexFailed, _LexError)
  )

primitive _Lexer
  """
  Split url to corresponding tokens by seperator.
  """
  fun apply(
    src: String val)
  : _LexResult =>

    try
      if src(0)? != '/' then
        return (_LexFailed, _LexErrorPatternMustStartWithSlash)
      end
    else
      return (_LexFailed, _LexErrorPatternMustStartWithSlash)
    end

    var state: _LexerState = _InitState
    let buf: String iso = recover iso String end
    let result: Array[_Token] iso = recover iso Array[_Token] end

    for chr in src.array().values() do
      match state
      | _InitState =>
        match chr
        | ' ' =>
          state = _InitState
        | '/' =>
          state = _InitState
        | ':' =>
          state = _PlaceholderState
        | '*' =>
          state = _WildcardState
        else
          buf.push(chr)
          state = _StaticState
        end
      | _PlaceholderState =>
        match chr
        | '/' =>
          if buf.size() > 0 then
            let buf' = buf.clone()
            result.push((_PlaceholderToken, consume buf'))
            buf.clear()
            state = _InitState
          else
            return (_LexFailed, _LexErrorPlaceholderNameEmpty)
          end
        | ':' =>
          return (_LexFailed, _LexErrorPlaceholderNameContainColonOrAsterisk)
        | '*' =>
          return (_LexFailed, _LexErrorPlaceholderNameContainColonOrAsterisk)
        else
          buf.push(chr)
        end
      | _StaticState =>
        match chr
        | '/' =>
          let buf' = buf.clone()
          result.push((_StaticToken, consume buf'))
          buf.clear()
          state = _InitState
        | ':' =>
          return (_LexFailed, _LexErrorStaticContainColonOrAsterisk)
        | '*' =>
          return (_LexFailed, _LexErrorStaticContainColonOrAsterisk)
        else
          buf.push(chr)
        end
      | _WildcardState =>
        match chr
        | '/' =>
          return (_LexFailed, _LexErrorWildcardShouldBeLastToken)
        | ':' =>
          return (_LexFailed, _LexErrorWildcardNameContainColonOrAsterisk)
        | '*' =>
          return (_LexFailed, _LexErrorWildcardNameContainColonOrAsterisk)
        else
          buf.push(chr)
        end
      end
    end
    if buf.size() > 0 then
      match state
      | _InitState =>
        result.push((_StaticToken, consume buf))
      | _PlaceholderState =>
        result.push((_PlaceholderToken, consume buf))
      | _StaticState =>
        result.push((_StaticToken, consume buf))
      | _WildcardState =>
        result.push((_WildcardToken, consume buf))
      end
    else
      match state
      | _InitState =>
        result.push((_StaticToken, ""))
      | _PlaceholderState =>
        return (_LexFailed, _LexErrorPlaceholderNameEmpty)
      | _WildcardState =>
        return (_LexFailed, _LexErrorWildcardNameEmpty)
      end
    end
    (_LexDone, consume result)

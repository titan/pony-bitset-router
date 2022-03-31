use "itertools"
use "pony_test"

class \nodoc\ _TestLexer is UnitTest
  fun name()
  : String =>
    "Lexer"

  fun apply(
    h: TestHelper)
  =>
    _test(
      h,
      "/posts/:post_id/comments/:id",
      [
        (_StaticToken, "posts")
        (_PlaceholderToken, "post_id")
        (_StaticToken, "comments")
        (_PlaceholderToken, "id")
      ]
    )
    _test(
      h,
      "/file/*file_path",
      [
        (_StaticToken, "file")
        (_WildcardToken, "file_path")
      ]
    )
    _test(
      h,
      "/",
      [
        (_StaticToken, "")
      ]
    )
    _test_error(
      h,
      "/file:",
      _LexErrorStaticContainColonOrAsterisk
    )
    _test_error(
      h,
      "/:",
      _LexErrorPlaceholderNameEmpty
    )
    _test_error(
      h,
      "/:file*",
      _LexErrorPlaceholderNameContainColonOrAsterisk
    )
    _test_error(
      h,
      "/*",
      _LexErrorWildcardNameEmpty
    )
    _test_error(
      h,
      "/*file_path:",
      _LexErrorWildcardNameContainColonOrAsterisk
    )
    _test_error(
      h,
      "/*file_path/",
      _LexErrorWildcardShouldBeLastToken
    )
    _test_error(
      h,
      "",
      _LexErrorPatternMustStartWithSlash
    )

  fun _test(
    h: TestHelper,
    src: String val,
    expect: Array[_Token val] val,
    loc: SourceLoc = __loc)
  =>
    match _Lexer(src)
    | (_LexDone, let actual: Array[_Token val] val) =>
      h.assert_eq[USize](actual.size(), expect.size())
      var ok: Bool = true
      var i: USize = 0
      try
        while i < expect.size() do
          if (expect(i)?._1 != actual(i)?._1) and (expect(i)?._2 != actual(i)?._2) then
            ok = false
            break
          end
          i = i + 1
        end
      else
        ok = false
      end

      if not ok then
        h.fail(_FormatLoc(loc) + "Assert EQ failed. Expected (" + _print_token_array(expect) + ") == (" + _print_token_array(actual) + ")")
      end
    | (_LexFailed, let err: _LexError) =>
      h.fail(_FormatLoc(loc) + err.string())
    end

  fun _test_error(
    h: TestHelper,
    src: String val,
    expect: _LexError,
    loc: SourceLoc = __loc)
  =>
    match _Lexer(src)
    | (_LexFailed, let err: _LexError) =>
      if err != expect then
        h.fail(_FormatLoc(loc) + "Expect " + expect.string() + " but got " + err.string())
      end
    | (_LexDone, let tokens: Array[_Token val] val) =>
      h.fail(_FormatLoc(loc) + "Expect " + expect.string() + " but it's " + _print_token_array(tokens))
    end

  fun _print_token_array(
    array: ReadSeq[_Token])
  : String =>
    "[len=" + array.size().string() + ": " + ", ".join(Iter[_Token](array.values()).map[String]({(x: _Token): String => "(" + x._1.string() + ", " + x._2.string()+ ")"})) + "]"

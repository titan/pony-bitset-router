use "itertools"
use "pony_test"

class \nodoc\ _TestRouter is UnitTest
  fun name()
  : String =>
    "Router"

  fun apply(
    h: TestHelper)
  =>
    _test_common(h)
    _test_single(h)
    _test_prefix(h)
    _test_collision(h)

  fun _test_common(
    h: TestHelper)
  =>
    let router = Router
    router.add("/user/:user-id")
    router.add("/user/:user-id/post/:post-id")
    router.add("/profile")
    router.add("/file/*filepath")
    router.add("/")
    let router': Router val = consume router

    _assert_router(h, router', "/user/12345678", 0, [("user-id", "12345678")])
    _assert_router(h, router', "/user/12345678/post/87654321", 1, [("user-id", "12345678"); ("post-id", "87654321")])
    _assert_router(h, router', "/profile", 2, [])
    _assert_router(h, router', "/file/home/user/.bashrc", 3, [("filepath", "home/user/.bashrc")])
    _assert_router(h, router', "/", 4, [])
    _assert_router(h, router', "/test", None, [])

  fun _test_single(
    h: TestHelper)
  =>
    let router = Router
    router.add("/hello/:name")
    let router': Router val = consume router

    _assert_router(h, router', "/hello/world", 0, [("name", "world")])
    _assert_router(h, router', "/hello/world/pony", None, [])
    _assert_router(h, router', "/hello", None, [])

  fun _test_prefix(
    h: TestHelper)
  =>
    let router = Router
    router.add("/hello/world/:name")
    router.add("/hello/pony/")
    router.add("/pony")
    let router': Router val = consume router

    _assert_router(h, router', "/hello", None, [])

  fun _test_collision(
    h: TestHelper)
  =>
    let router0 = Router
    match router0.add("/u/:id/p/:id")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router0.add("/u/:uid/p/:pid")
    | let index: USize val =>
      h.fail("Expect an error but got " + index.string() + " from router 0")
    end

    let router1 = Router
    match router1.add("/u/:id/p/:id")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router1.add("/u/:uid/p")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end

    let router2 = Router
    match router2.add("/u/:id/*test")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router2.add("/u/:id/")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end

    let router3 = Router
    match router3.add("/u/:id/*test")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router3.add("/u/:id/*test")
    | let index: USize val =>
      h.fail("Expect an error but got " + index.string() + " from router 3")
    end

    let router4 = Router
    match router4.add("/application/c/:a")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router4.add("/application/b")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end
    match router4.add("/application/b/:id")
    | let err: String =>
      h.fail("Expect result to be None but got " + err)
    end

  fun _assert_router(
    h: TestHelper,
    router: Router val,
    path: String val,
    index: (USize val | None),
    captures: Array[(String val, String val)] val)
  =>
    let actual = router.find(path)
    match index
    | None =>
      match actual
      | None =>
        None
      | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
        h.fail("Expect None result but got index: " + idx.string() + " and captures: " + _print_capture_array(captures'))
      end
    | let index': USize val =>
      match actual
      | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
        h.assert_eq[USize val](index', idx)
        _assert_capture_array_eq(h, captures, captures')
      | None =>
        h.fail("Expect index: " + index'.string() + " and captures: " + _print_capture_array(captures) + ", but got None")
      end
    end

  fun _print_capture_array(
    array: ReadSeq[(String val, String val)])
  : String =>
    "[" + ", ".join(Iter[(String val, String val)](array.values()).map[String]({(x: (String val, String val)): String => "(" + x._1 + ", " + x._2 + ")"})) + "]"

  fun _assert_capture_array_eq(
    h: TestHelper,
    expect: ReadSeq[(String val, String val)],
    actual: ReadSeq[(String val, String val)],
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    var ok = true

    if expect.size() != actual.size() then
      ok = false
    else
      try
        var i: USize = 0
        while i < expect.size() do
          if (expect(i)?._1 != actual(i)?._1) or (expect(i)?._2 != actual(i)?._2) then
            ok = false
            break
          end

          i = i + 1
        end
      else
        ok = false
      end
    end

    if not ok then
      h.fail(_FormatLoc(loc) + "Assert EQ failed. " + msg + " Expected ("
        + _print_capture_array(expect) + ") == (" + _print_capture_array(actual) + ")")
      return false
    end

    true

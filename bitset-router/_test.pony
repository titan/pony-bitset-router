use "pony_test"

primitive \nodoc\ _FormatLoc
  fun apply(
    loc: SourceLoc)
  : String =>
    loc.file() + ":" + loc.line().string() + ": "

actor \nodoc\ Main is TestList
  new create(
    env: Env)
  =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(
    test: PonyTest)
  =>
    test(_TestLexer)
    test(_TestBitSet)
    test(_TestRouter)

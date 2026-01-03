module req::http1;

import std::io;

struct ParserTestFixture
{
    ParserStep parser;
    Response response;
    ParserResult result;
}

fn void ParserTestFixture.init(&self, ParserStep parser)
{
    self.parser = parser;
    self.response.tinit();
}

fn ParserResult ParserTestFixture.parse(&self, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!!;

    ParserResult result;
    while (try current = buf.read_byte())
    {
        result = self.parser.step(current, &self.response)!!;
    }

    return result;
}

<*
  A test helper to allow the caller to pass the test input and any Parser
  implementation.

  The function will setup all the required dependencies, execute the tests and
  then return the results in the ParserTestFixture.
*>
macro void? @run_parser_test_fixture(String input, ParserStep parser; @test_asserts(ParserTestFixture* fixture))
{
    ParserTestFixture fixture;
    fixture.init(parser);

    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    while (try current = buf.read_byte())
    {
        fixture.result = fixture.parser.step(current, &fixture.response)!;
    }
    @test_asserts(&fixture);
}

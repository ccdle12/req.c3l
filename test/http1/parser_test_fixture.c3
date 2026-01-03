module req::http1;

import std::io;

struct ParserTestFixture
{
    HttpStepParser parser;
    Response response;
    HttpParserResult result;
}

fn void ParserTestFixture.init(&self, HttpStepParser parser)
{
    self.parser = parser;
    self.response.tinit();
}

fn HttpParserResult ParserTestFixture.parse(&self, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!!;

    HttpParserResult result;
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
macro void? @run_parser_test_fixture(String input, HttpStepParser parser; @test_asserts(ParserTestFixture* fixture))
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

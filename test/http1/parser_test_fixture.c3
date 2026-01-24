module req::http1;

import std::io;

<*
  This test fixture is used for all structs that implement HttpResponseStepParser. It
  will setup all the dependencies before each test and drive the results.
*>
struct ParserTestFixture
{
    HttpResponseStepParser parser;
    HttpResponse response;
    HttpParserResult result;
}

fn void ParserTestFixture.init(&self, HttpResponseStepParser parser)
{
    self.parser = parser;
    self.response.tinit();
}

<*
  This helper function will drive the HttpResponseStepParser, advancing through the
  state machine given input.
*>
fn HttpParserResult? ParserTestFixture.parse(&self, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    while (try byte = buf.read_byte())
    {
        self.result = self.parser.step(byte, &self.response)!;
    }

    return self.result;
}

<*
  A test helper to allow the caller to pass the test input and any Parser
  implementation.

  The function will setup all the required dependencies, execute the test assertions
  and return the results in the ParserTestFixture.
*>
macro void? @run_parser_test_fixture(String input, HttpResponseStepParser parser; @test_asserts(ParserTestFixture* fixture))
{
    ParserTestFixture fixture;
    fixture.init(parser);
    fixture.parse(input)!;
    @test_asserts(&fixture);
}

module req::http1;

import std::io;

<*
  This test fixture is used for all structs that implement HttpResponseStepParser. It
  will setup all the dependencies before each test and drive the results.
*>
struct ParserTestFixture
{
    // Any parser used in both HttpResponse and HttpRequest structs.
    any parser;
    HttpResponse response;
    HttpParserResult result;
}

fn void ParserTestFixture.init(&self, any parser)
{
    self.parser = parser;
    self.response.tinit();
}

<*
  A test helper to allow the caller to pass the test input and any Parser
  implementation.

  The function will setup all the required dependencies, execute the test assertions
  and return the results in the ParserTestFixture.
*>
macro void? @run_parser_test_fixture(String input, parser, parse_step_fn; @test_asserts(ParserTestFixture* fixture))
{
    ParserTestFixture fixture;
    fixture.init(&parser);
    parse_step_fn(&fixture, input)!;
    @test_asserts(&fixture);
}

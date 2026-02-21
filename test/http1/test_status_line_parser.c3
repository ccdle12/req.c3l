module req::http1;

import std::io;

fn HttpParserResult? status_line_parse_step(ParserTestFixture* fixture, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    // I need this to be a solid type.
    StatusLineParser* parser = (StatusLineParser*) fixture.parser;

    while (try byte = buf.read_byte())
    {
        fixture.result = parser.step(byte, &fixture.response)!;
    }

    return fixture.result;
}

<*
  A test helper to setup the ParserTestFixture using the StatusLineParser for
  each test.
*>
macro void? @run_status_line_fixture(String input; @test_asserts(ParserTestFixture* fixture))
{
    StatusLineParser parser;
    parser.init(tmem);

    @run_parser_test_fixture(input, parser, &status_line_parse_step; ParserTestFixture* fixture)
    {
        @test_asserts(fixture);
    }!;
}

fn fault assert_status_line_error(String input)
{
    return @catch(@run_status_line_fixture(input; ParserTestFixture* fixture){});
}

//// Test for RFC compliance. ////

// RFC9112: https://www.rfc-editor.org/rfc/rfc9112#section-4-1
// Test that the textual phrase describing the status code is OPTIONAL.
fn void test_basic_status_line_0() @test
{
   String input = "HTTP/1.1 200\r\n";
   @run_status_line_fixture(input; ParserTestFixture* fixture)
   {
       test::eq(fixture.response.http_version, "HTTP/1.1");
       test::eq(fixture.response.status_code, 200);
       test::eq(fixture.result, HttpParserResult.COMPLETE);
   }!!;
}

// Test that we can have an optional reason.
fn void test_status_line_with_reason() @test
{
   String input = "HTTP/1.1 200 OK\r\n";
   @run_status_line_fixture(input; ParserTestFixture* fixture)
   {
       test::eq(fixture.response.http_version, "HTTP/1.1");
       test::eq(fixture.response.status_code, 200);
       test::eq(fixture.response.reason_phrase, "OK");
       test::eq(fixture.result, HttpParserResult.COMPLETE);
   }!!;
}

// RFC 9110 15.5 - status code MUST be a 3 digit number.
fn void invalid_status_code_length() @test
{
    String input = "HTTP/1.1 40001 OK\r\n";
    test::eq(assert_status_line_error(input), INVALID_STATUS_CODE);
}

//// Test for errors. ////

fn void test_incorrect_http_version() @test
{
   String input = "HTTP/2.0 200\r\n";
   test::eq(assert_status_line_error(input), INVALID_PROTOCOL_VERSION);
}

fn void test_missing_status_code() @test
{
   String input = "HTTP/1.0\r\n";
   @run_status_line_fixture(input; ParserTestFixture* fixture)
   {
       test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
   }!!;
}

fn void test_empty_input() @test
{
   String input = "";
   @run_status_line_fixture(input; ParserTestFixture* fixture)
   {
       test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
   }!!;
}

fn void test_single_malformed_lf() @test
{
   String input = "\n";
   @run_status_line_fixture(input; ParserTestFixture* fixture)
   {
       test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
   }!!;
}

fn void test_invalid_status_code() @test
{
    String input = "HTTP/1.1 foo OK\r\n";
    test::eq(assert_status_line_error(input), INVALID_STATUS_CODE);
}

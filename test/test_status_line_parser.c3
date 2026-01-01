module req;

import std::io;

<*
  A test helper function to repeat setting up the parser, buffer and response.

  The caller passes the string input as an arg and the test assertions in the
  body.

*>
macro void? @status_line_test(String input; @test_asserts(Response response, StatusLineParser parser, ParserResult result))
{
    StatusLineParser parser;
    parser.init(tmem);

    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    Response response;
    response.tinit();

    ParserResult result;
    while (buf.read_idx < buf.write_idx)
    {
        char current = buf.read_byte()!;
        result = parser.step(current, &response)!;
    }
    @test_asserts(response, parser, result);
}

fn fault status_line_error_test(String input)
{
    return @catch(@status_line_test(input; Response response, StatusLineParser parser, ParserResult result){});
}

//// Test for RFC compliance. ////

// RFC9112: https://www.rfc-editor.org/rfc/rfc9112#section-4-1
// Test that the textual phrase describing the status code is OPTIONAL.
fn void test_basic_status_line_0() @test
{
   String input = "HTTP/1.1 200\r\n";

   (void)@status_line_test(input; Response response, StatusLineParser parser, ParserResult result)
   {
       test::eq(response.http_version, "HTTP/1.1");
       test::eq(response.status_code, 200);
       test::eq(result, ParserResult.COMPLETE);
   };
}

// Test that we can have an optional reason.
fn void test_status_line_with_reason() @test
{
   String input = "HTTP/1.1 200 OK\r\n";

   (void)@status_line_test(input; Response response, StatusLineParser parser, ParserResult result)
   {
       test::eq(response.http_version, "HTTP/1.1");
       test::eq(response.status_code, 200);
       test::eq(response.reason_phrase, "OK");
       test::eq(parser.state, StatusLineState.COMPLETE);
   };
}

// RFC 9110 15.5 - status code MUST be a 3 digit number.
fn void invalid_status_code_length() @test
{
    String input = "HTTP/1.1 40001 OK\r\n";
    test::eq(status_line_error_test(input), INVALID_STATUS_CODE);
}

//// Test for errors. ////

fn void test_incorrect_http_version() @test
{
   String input = "HTTP/2.0 200\r\n";
   test::eq(status_line_error_test(input), INVALID_PROTOCOL_VERSION);
}

fn void test_missing_status_code() @test
{
   String input = "HTTP/1.0\r\n";
   (void)@status_line_test(input; Response response, StatusLineParser parser, ParserResult result)
   {
       test::eq(result, ParserResult.REQUEST_MORE);
   };
}

fn void test_empty_input() @test
{
   String input = "";
   (void)@status_line_test(input; Response response, StatusLineParser parser, ParserResult result)
   {
       test::eq(result, ParserResult.REQUEST_MORE);
   };
}

fn void test_single_malformed_lf() @test
{
   String input = "\n";
   (void)@status_line_test(input; Response response, StatusLineParser parser, ParserResult result)
   {
       test::eq(result, ParserResult.REQUEST_MORE);
   };
}

fn void test_invalid_status_code() @test
{
    String input = "HTTP/1.1 foo OK\r\n";
    test::eq(status_line_error_test(input), INVALID_STATUS_CODE);
}

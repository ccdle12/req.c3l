module req;

// RFC9112: https://www.rfc-editor.org/rfc/rfc9112#section-4-1
// A the textual phrase describing the status code is OPTIONAL.
fn void test_basic_status_line() @test
{
   String input =
      "HTTP/1.1 200\r\n";

   Parser parser;
   parser.tinit();
   parser.step(input)!!;

   test::eq(parser.response.http_version, "HTTP/1.1");
   test::eq(parser.response.status_code, 200);
   test::eq(parser.state, ParserState.HEADER);
}

fn void test_status_line_with_reason() @test
{
   String input =
      "HTTP/1.1 200 OK\r\n";

   Parser parser;
   parser.tinit();
   parser.step(input)!!;

   test::eq(parser.response.http_version, "HTTP/1.1");
   test::eq(parser.response.status_code, 200);
   test::eq(parser.response.reason_phrase, "OK");
   test::eq(parser.state, ParserState.HEADER);
}

fn void test_incorrect_http_version() @test
{
   String input =
      "HTTP/2.0 200\r\n";

   Parser parser;
   parser.tinit();

   fault excuse = @catch(parser.step(input));
   test::eq(excuse, INVALID_PROTOCOL_VERSION);
}

fn void test_missing_status_code() @test
{
   String input =
      "HTTP/1.0\r\n";

   Parser parser;
   parser.tinit();

   test::eq(parser.step(input)!!, ParserState.REQUEST_MORE);
}

fn void test_empty_input() @test
{
   String input = "";

   Parser parser;
   parser.tinit();

   test::eq(parser.step(input)!!, ParserState.REQUEST_MORE);
}

fn void test_single_malformed_lf() @test
{
   String input = "\n";

   Parser parser;
   parser.tinit();

   test::eq(parser.step(input)!!, ParserState.REQUEST_MORE);
}

fn void test_invalid_status_code() @test
{
    String input =
        "HTTP/1.1 foo OK\r\n";

    Parser parser;
    parser.tinit();

    test::eq(@catch(parser.step(input)), INVALID_STATUS_CODE);
}

// RFC 9110 15.5 - status code MUST be a 3 digit number.
fn void invalid_status_code_length() @test
{
    String input =
        "HTTP/1.1 40001 OK\r\n";

    Parser parser;
    parser.tinit();

    test::eq(@catch(parser.step(input)), INVALID_STATUS_CODE);
}

fn void empty_status_line() @test
{
    String input = "";

    Parser parser;
    parser.tinit();

    assert(parser.step(input)!! == ParserState.REQUEST_MORE);
}

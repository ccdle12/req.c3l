module req;

fn void test_status_line_ok() @test
{
   String input =
      "HTTP/1.1 200 OK \r\n";

   Response response;
   response.init(tmem);
   response.parse_status_line(input)!!;

   test::eq(response.http_version, "HTTP/1.1");
   test::eq(response.status_code, 200);
   test::eq(response.reason_phrase, "OK");
}

// RFC9112: https://www.rfc-editor.org/rfc/rfc9112#section-4-1
// A the textual phrase describing the status code is OPTIONAL.
fn void test_missing_reason_phrase() @test
{
   String input =
      "HTTP/1.1 200 \r\n";

   Response response;
   response.init(tmem);
   response.parse_status_line(input)!!;

   test::eq(response.status_code, 200);
}

fn void test_incorrect_http_version() @test
{
   String input =
      "HTTP/2.0 200\r\n";

   Response response;
   response.init(tmem);
   fault excuse = @catch(response.parse_status_line(input));
   test::eq(excuse, INVALID_PROTOCOL_VERSION);
}

fn void test_http_10_version() @test
{
   String input =
      "HTTP/1.0 200 \r\n";

   Response response;
   response.init(tmem);
   response.parse_status_line(input)!!;

   test::eq(response.http_version, "HTTP/1.0");
}

fn void test_missing_status_code() @test
{
   String input =
      "HTTP/1.0\r\n";

   Response response;
   response.init(tmem);
   fault excuse = @catch(response.parse_status_line(input));
   test::eq(excuse, MALFORMED_STATUS_LINE);
}

fn void test_missing_carriage_return() @test
{
   String input = "";

   Response response;
   response.init(tmem);
   fault excuse = @catch(response.parse_status_line(input));
   test::eq(excuse, MALFORMED_STATUS_LINE);
}

fn void test_single_malformed_lf() @test
{
   String input = "\n";

   Response response;
   response.init(tmem);

   fault excuse = @catch(response.parse_status_line(input));
   test::eq(excuse, MALFORMED_STATUS_LINE);
}

fn void test_invalid_status_code() @test
{
    String input =
        "HTTP/1.1 foo OK\r\n";

    Parser parser;
    parser.tinit();

    assert(@catch(parser.step(input)) == INVALID_STATUS_CODE);
}

fn void invalid_status_code_length() @test
{
    String input =
        "HTTP/1.1 40001 OK\r\n";

    Parser parser;
    parser.tinit();

    assert(@catch(parser.step(input)) == INVALID_STATUS_CODE);
}

fn void empty_status_line() @test
{
    String input = "";

    Parser parser;
    parser.tinit();

    assert(parser.step(input)!! == ParserState.EOF);
}

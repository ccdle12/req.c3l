module req;

import tora;
import std::io;

fn void test_incomplete_header() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input);

    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.START);
}

fn void test_only_header() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n"
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n"
      "via: 1.1 Caddy \r\n"
      "transfer-encoding: chunked"
      "\r\n\r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input);

    test::eq(state, ParserState.HEADER_DONE);
    test::eq(parser.state, ParserState.HEADER_DONE);
    test::@check(input == parser.buf_str_view());
}

fn void test_incremental_read() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input);

    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.START);
    test::@check(input == parser.buf_str_view());

    String second_input =
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n";

    state = parser.step(second_input);

    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.START);
    test::@check(parser.buf_str_view().contains(second_input));

    String third_input =
      "transfer-encoding: chunked";

    state = parser.step(third_input);

    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.START);
    test::@check(parser.buf_str_view().contains(third_input));

    String final_input =
      "\r\n\r\n";

    state = parser.step(final_input);

    test::eq(state, ParserState.HEADER_DONE);
    test::eq(parser.state, ParserState.HEADER_DONE);
    test::@check(parser.buf_str_view().contains(third_input));
}

fn void test_chunked_body_type() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n"
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n"
      "via: 1.1 Caddy \r\n"
      "transfer-encoding: chunked"
      "\r\n\r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input);

    test::eq(state, ParserState.HEADER_DONE);
    test::eq(parser.state, ParserState.HEADER_DONE);
    test::eq(parser.response.body_type, BodyType.CHUNKED);
}

fn void test_parse_header() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n"
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n"
      "via: 1.1 Caddy \r\n"
      "transfer-encoding: chunked"
      "\r\n\r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input);

    test::eq(parser.response.http_version, "HTTP/1.1");
    test::eq(parser.response.status_code, "200");
    test::eq(parser.response.reason_phrase, "OK");
}

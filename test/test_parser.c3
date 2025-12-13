module req;

import tora;
import std::io;

fn void test_incomplete_header() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input)!!;

    // We should have moved to the header state but we need more bytes.
    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.HEADER);
}

fn void test_with_allocator() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n"
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "Date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n"
      "via: 1.1 Caddy \r\n"
      "transfer-encoding: chunked \r\n"
      "\r\n";

    LibcAllocator alloc;

    Parser parser;
    parser.init(&alloc);
    defer parser.free();

    ParserState state = parser.step(input)!!;

    // We should have moved to the header state but we need more bytes.
    test::eq(state, ParserState.BODY);
}

fn void test_full_header() @test
{
    String input =
      "HTTP/1.1 200 OK \r\n"
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "Date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n"
      "via: 1.1 Caddy \r\n"
      "transfer-encoding: chunked \r\n"
      "\r\n";

    Parser parser;
    parser.tinit();

    test::eq(parser.step(input)!!, ParserState.BODY);
    test::eq(parser.state, ParserState.BODY);
    test::@check(parser.buf_str_view().contains(input));

    test::eq(*parser.response.get_header_ref("access-control-allow-origin")!!, "*");
    test::eq(*parser.response.get_header_ref("content-type")!!, "application/json");
    test::eq(*parser.response.get_header_ref("date")!!, "Sat, 16 Aug 2025 21:48:49 GMT");
    test::eq(*parser.response.get_header_ref("vary")!!, "Accept-Encoding");
    test::eq(*parser.response.get_header_ref("via")!!, "1.1 Caddy");
    test::eq(*parser.response.get_header_ref("transfer-encoding")!!, "chunked");
}

fn void test_incremental_read() @test
{
    Parser parser;
    parser.tinit();

    String input_0 =
        "HTTP/1.1 200 OK \r\n";

    test::eq(parser.step(input_0)!!, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.HEADER);
    test::@check(parser.buf_str_view().contains(input_0));

    String input_1 =
      "access-control-allow-origin: *\r\n"
      "content-type: application/json \r\n"
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n";

    test::eq(parser.step(input_1)!!, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.HEADER);
    test::@check(parser.buf_str_view().contains(input_1));

    String input_2 =
      "transfer-encoding: chunked";

    test::eq(parser.step(input_2)!!, ParserState.REQUEST_MORE);
    test::eq(parser.state, ParserState.HEADER);
    test::@check(parser.buf_str_view().contains(input_2));

    String input_3 =
      "\r\n\r\n";

    test::eq(parser.step(input_3)!!, ParserState.BODY);
    test::eq(parser.state, ParserState.BODY);
    test::@check(parser.buf_str_view().contains(input_3));
}

fn void test_headers_without_double_crlf() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0";

    Parser parser;
    parser.tinit();

    test::eq(parser.step(input)!!, ParserState.REQUEST_MORE);
}


// TODO: This should be detected some how? the length of the long header
// with multiple headers could be considered value.
//fn void test_missing_crlf() @test
//{
//    String input =
//        "HTTP/1.1 200 OK \r\n"
//        "Content-Type: application/json\r\n"
//        "Content-Length: 115 \r\n"
//        "Connection: keep-alive"
//        "Date: Wed, 13 Aug 2025 12:00:00 GMT"
//        "Server: nginx/1.18.0 \r\n"
//        "\r\n";
//
//    Parser parser;
//    parser.tinit();
//
//    fault excuse = @catch(parser.step(input));
//    test::eq(excuse, INVALID_HEADER_KEY_SYMBOL);
//}

// RFC 9112, Section 6.1: Message Body Length
// If transfer-encoding and content-length are missing, then the message is still
// valid but the body length is assumed to be 0.
fn void test_no_body_type() @test
{
   String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0 \r\n"
        "\r\n"
        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}"
        "0\r\n\r\n";

   Response response;
   response.tinit();

   test::eq(response.body_type, BodyType.NULL);
}

// According to RFC9112 6.1:
// There is a priortiy rule that emphasizes that Transfer-Encoding has precedence
// over Content-Length.
//
// TODO: 2025.12.03 - according to the RFC, the server MUST close the connection
// after sending the response after receiving both Transfer-Encoding AND Content-Length
// due to mitigating "Request Smuggling" attacks.
fn void test_transfer_encoding_priority() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0 \r\n"
        "transfer-encoding: chunked \r\n"
        "\r\n"
        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}"
        "0\r\n\r\n";

    Parser parser;
    parser.tinit();

    parser.step(input)!!;
    test::eq(parser.response.body_type, BodyType.CHUNKED);
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
        "transfer-encoding: chunked \r\n"
        "\r\n";

    Parser parser;
    parser.tinit();

    ParserState state = parser.step(input)!!;
    test::eq(parser.response.body_type, BodyType.CHUNKED);
}

fn void test_missing_trailing_crlf() @test
{
    String input =
        "HTTP/1.1 200 OK";

    Parser parser;
    parser.tinit();

    assert(parser.step(input)!! == ParserState.REQUEST_MORE);
}

fn void test_missing_trailing_lf() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r";

    Parser parser;
    parser.tinit();

    assert(parser.step(input)!! == REQUEST_MORE);
}

fn void test_lone_lf() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \n";

    Parser parser;
    parser.tinit();

    assert(@catch(parser.step(input)) == MALFORMED_CRLF);
}

fn void test_malformed_crlf_0() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r"
        "Server: nginx/1.18.0";

    Parser parser;
    parser.tinit();

    test::eq(@catch(parser.step(input)), MALFORMED_CRLF);
}

fn void test_malformed_crlf_1() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \rfoo\n";

    Parser parser;
    parser.tinit();

    assert(@catch(parser.step(input)) == MALFORMED_CRLF);
}

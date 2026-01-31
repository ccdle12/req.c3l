module req::http1;

import std::io;

fn void test_request_line() @test
{
    String input = "GET /search?name=John&age=30 HTTP/1.1\r\n";

    HttpRequest request;
    request.tinit();

    HttpRequestParser parser;
    parser.tinit();

    HttpParserResult result = parser.step(input, &request)!!;
    test::eq(parser.state, HttpRequestParserState.HEADER);
    test::eq(result, HttpParserResult.REQUEST_MORE);
}

fn void test_request_headers() @test
{
    String input = "GET /search?name=John&age=30 HTTP/1.1\r\n"
                   "Host: example.com\r\n"
                   "user-agent: Mozilla/5.0\r\n"
                   "accept: application/json\r\n"
                   "\r\n";

    HttpRequest request;
    request.tinit();

    HttpRequestParser parser;
    parser.tinit();

    HttpParserResult result = parser.step(input, &request)!!;
    test::eq(parser.state, HttpRequestParserState.COMPLETE);
    test::eq(result, HttpParserResult.COMPLETE);
}

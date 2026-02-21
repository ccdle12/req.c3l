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
    test::eq(parser.state, HttpRequestParserState.BODY);
    test::eq(result, HttpParserResult.REQUEST_MORE);
    test::eq(request.path, "/search?name=John&age=30");
    test::eq(request.host, "example.com");
}

fn void test_post_request() @test
{
    String input = "POST /api/test HTTP/1.1\r\n"
                   "Host: example.com\r\n"
                   "user-agent: Mozilla/5.0\r\n"
                   "content-type: application/json\r\n"
                   "content-length: 27\r\n"
                   "authorization: Bearer ACCESS_TOKEN\r\n"
                   "\r\n"
                   "{\r\n"
                   "\t\"name\": \"John Doe\"\r\n"
                   "}\r\n"
                   "\r\n";

    HttpRequest request;
    request.tinit();

    HttpRequestParser parser;
    parser.tinit();

    HttpParserResult result = parser.step(input, &request)!!;
    test::eq(parser.state, HttpRequestParserState.COMPLETE);
    test::eq(result, HttpParserResult.COMPLETE);

    test::eq(request.body.str_view(), "{\r\n\t\"name\": \"John Doe\"\r\n}\r\n");
}

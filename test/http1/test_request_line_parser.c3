
module req::http1;

import std::io;

struct RequestLineTestFixture
{
    RequestLineParser parser;
    HttpRequest request;
    HttpParserResult result;
}

fn void RequestLineTestFixture.init(&self, RequestLineParser parser)
{
    self.parser = parser;
    self.request.init(tmem);
}

fn HttpParserResult? RequestLineTestFixture.parse(&self, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    while (try byte = buf.read_byte())
    {
        self.result = self.parser.step(byte, &self.request)!;
    }

    return self.result;
}

macro void? @run_request_line_test(String input; @test_asserts(RequestLineTestFixture* fixture))
{
    RequestLineTestFixture fixture;

    RequestLineParser parser;
    parser.init(tmem);

    fixture.init(parser);
    fixture.parse(input)!;

    @test_asserts(&fixture);
}

fn fault assert_request_line_error(String input)
{
    return @catch(@run_request_line_test(input; RequestLineTestFixture* fixture){});
}

fn void test_basic_request_line() @test
{
    String input = "GET /index.html HTTP/1.1\r\n";

    @run_request_line_test(input; RequestLineTestFixture* fixture)
    {
        test::eq(fixture.request.type, RequestType.GET);
        test::eq(fixture.request.path, "/index.html");
        test::eq(fixture.request.http_version, "HTTP/1.1");
        test::eq(fixture.result, HttpParserResult.COMPLETE);
    }!!;
}

fn void test_delayed_request_line() @test
{
    String input = "POST";

    @run_request_line_test(input; RequestLineTestFixture* fixture)
    {
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
        test::@check(fixture.request.type != RequestType.POST);

        HttpParserResult result = fixture.parse(" ")!!;
        test::eq(fixture.request.type, RequestType.POST);
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);

        result = fixture.parse("/api/v2")!!;
        test::eq(fixture.request.path, "");
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);

        result = fixture.parse(" ")!!;
        test::eq(fixture.request.path, "/api/v2");
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);

        result = fixture.parse("HTTP/1.1")!!;
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);

        result = fixture.parse("\r")!!;
        test::eq(fixture.request.http_version, "HTTP/1.1");
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);

        result = fixture.parse("\n")!!;
        test::eq(fixture.result, HttpParserResult.COMPLETE);
    }!!;
}

fn void test_malformed_request_line() @test
{
    String input = "POST /api/v2\r\n";

    test::eq(assert_request_line_error(input), INVALID_REQUEST_MISSING_HTTP_VERSION);
}

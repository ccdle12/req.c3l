module req::http1;

import std::collections;
import std::io;

fn void test_request_init() @test
{
    HttpRequest request;
    request.tinit();

    String expected = "GET /search?name=John&age=30 HTTP/1.1\r\n"
                      "Host: example.com\r\n"
                      "user-agent: Mozilla/5.0\r\n"
                      "accept: application/json\r\n"
                      "\r\n";

    request.type = RequestType.GET;
    request.path = "/search?name=John&age=30";
    request.http_version = "HTTP/1.1";
    request.host = "example.com";

    request.headers.push("User-Agent", "Mozilla/5.0")!!;
    request.headers.push("Accept", "application/json")!!;

    String result = request.to_string(tmem)!!;
    test::eq(expected, result);
}

fn void test_request_to_string_with_body() @test
{
    HttpRequest request;
    request.tinit();

    String expected = "POST /api/test HTTP/1.1\r\n"
                      "Host: example.com\r\n"
                      "user-agent: Mozilla/5.0\r\n"
                      "content-type: application/json\r\n"
                      "content-length: 20\r\n"
                      "authorization: Bearer ACCESS_TOKEN\r\n"
                      "\r\n"
                      "{\r\n"
                      "\t\"name\": \"John Doe\"\r\n"
                      "}\r\n"
                      "\r\n";

    request.type = RequestType.POST;
    request.path = "/api/test";
    request.http_version = "HTTP/1.1";
    request.host = "example.com";

    request.headers.push("User-Agent", "Mozilla/5.0")!!;
    request.headers.push("Content-Type", "application/json")!!;
    request.headers.push("Content-Length", "20")!!;
    request.headers.push("Authorization", "Bearer ACCESS_TOKEN")!!;

    String body = "{\r\n"
                  "\t\"name\": \"John Doe\"\r\n"
                  "}\r\n";

    request.body.appendf("%s", body);

    String result = request.to_string(tmem)!!;
    test::eq(expected, result);
}

fn void test_request_to_string_with_multiple_headers() @test
{
    HttpRequest request;
    request.tinit();

    String expected = "POST /api/test HTTP/1.1\r\n"
                      "Host: example.com\r\n"
                      "user-agent: Mozilla/5.0\r\n"
                      "content-type: application/json\r\n"
                      "content-length: 20\r\n"
                      "authorization: Bearer ACCESS_TOKEN\r\n"
                      "accept-encoding: gzip, deflate, br\r\n"
                      "\r\n"
                      "{\r\n"
                      "\t\"name\": \"John Doe\"\r\n"
                      "}\r\n"
                      "\r\n";

    request.type = RequestType.POST;
    request.path = "/api/test";
    request.http_version = "HTTP/1.1";
    request.host = "example.com";

    request.headers.push("User-Agent", "Mozilla/5.0")!!;
    request.headers.push("Content-Type", "application/json")!!;
    request.headers.push("Content-Length", "20")!!;
    request.headers.push("Authorization", "Bearer ACCESS_TOKEN")!!;
    request.headers.push("Accept-Encoding", "gzip")!!;
    request.headers.push("Accept-Encoding", "deflate")!!;
    request.headers.push("Accept-Encoding", "br")!!;

    String body = "{\r\n"
                  "\t\"name\": \"John Doe\"\r\n"
                  "}\r\n";

    request.body.appendf("%s", body);

    String result = request.to_string(tmem)!!;
    test::eq(expected, result);
}

fn void test_ser_der_http_request() @test
{
    HttpRequest request;
    request.tinit();

    String expected_str = "POST /api/test HTTP/1.1\r\n"
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

    request.type = RequestType.POST;
    request.path = "/api/test";
    request.http_version = "HTTP/1.1";
    request.host = "example.com";

    request.headers.push("User-Agent", "Mozilla/5.0")!!;
    request.headers.push("Content-Type", "application/json")!!;
    request.headers.push("Content-Length", "27")!!;
    request.headers.push("Authorization", "Bearer ACCESS_TOKEN")!!;

    String body = "{\r\n"
                  "\t\"name\": \"John Doe\"\r\n"
                  "}\r\n";

    // Assert the body is deserialized correctly.
    request.body.appendf("%s", body);
    test::eq(request.body.str_view(), body);

    // Check that serializing to buffer was correct.
    String result = request.to_string(tmem)!!;
    char[] ser_str = (char[]) result;

    String der_str = (String) ser_str;
    test::eq(expected_str, der_str);

    // Test that deserialiazing the HttpRequest is correct.
    HttpRequest der_request;
    der_request.tinit();

    HttpRequestParser parser;
    parser.tinit();
    parser.step(ser_str, &der_request)!!;

    test::eq(request.type, der_request.type);
    test::eq(request.path, der_request.path);
    test::eq(request.http_version, der_request.http_version);
    test::eq(request.host, der_request.host);
    test::eq(request.body, der_request.body);

    // We know the that each header is a singleton so we will retrieve the values
    // using the 0 index position. In most cases, the caller will need to check
    // the HeaderType.
    Header* user_agent = der_request.get_header_ref(USER_AGENT_KEY)!!;
    test::eq(user_agent.values[0], "Mozilla/5.0");

    Header* content_type = der_request.get_header_ref(CONTENT_TYPE_KEY)!!;
    test::eq(content_type.values[0], "application/json");

    Header* content_length = der_request.get_header_ref(CONTENT_LENGTH_KEY)!!;
    test::eq(content_length.values[0], "27");

    Header* authorization = der_request.get_header_ref(AUTHORIZATION_KEY)!!;
    test::eq(authorization.values[0], "Bearer ACCESS_TOKEN");
}

fn void test_ser_chunked_body_exts() @test
{
    String expected = "POST /api/test HTTP/1.1\r\n"
                      "Host: example.com\r\n"
                      "user-agent: Mozilla/5.0\r\n"
                      "Transfer-Encoding: chunked\r\n"
                      "content-type: application/json\r\n"
                      "authorization: Bearer ACCESS_TOKEN\r\n"
                      "\r\n"
                      "4;ext1=val1;flag\r\n"
                      "Wiki\r\n"
                      "5\r\n"
                      "pedia\r\n"
                      "E\r\n"
                      " in\r\n"
                      "\r\n"
                      "chunks.\r\n"
                      "0\r\n"
                      "\r\n";

    HttpRequest request;
    request.tinit();

    HttpRequestParser parser;
    parser.tinit();

    HttpParserResult result = parser.step(expected, &request)!!;
    test::eq(parser.state, HttpRequestParserState.COMPLETE);
    test::eq(result, HttpParserResult.COMPLETE);
    test::eq(request.body_type, BodyType.CHUNKED);

    HashMap{String, String}* map = &request.extensions;
    test::@check(*map.get_ref("ext1")!! == "val1");
    test::@check(*map.get_ref("flag")!! == "flag");
}

module req::http1;

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
    request.host = "example.com";
    request.http_version = "HTTP/1.1";

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
    request.host = "example.com";
    request.http_version = "HTTP/1.1";

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
    request.host = "example.com";
    request.http_version = "HTTP/1.1";

    request.headers.push("User-Agent", "Mozilla/5.0")!!;
    request.headers.push("Content-Type", "application/json")!!;
    request.headers.push("Content-Length", "27")!!;
    request.headers.push("Authorization", "Bearer ACCESS_TOKEN")!!;

    String body = "{\r\n"
                  "\t\"name\": \"John Doe\"\r\n"
                  "}\r\n";

    request.body.appendf("%s", body);
    test::eq(request.body.str_view(), body);

    String result = request.to_string(tmem)!!;
    char[] ser_str = (char[]) result;

    // Check that serializing to buffer was correct.
    String der_str = (String) ser_str;
    test::eq(expected_str, der_str);

    HttpRequest der_request;
    der_request.tinit();

    HttpRequestParser parser;
    parser.tinit();
    parser.step(ser_str, &der_request)!!;

    test::eq(request.type, der_request.type);
    test::eq(request.path, der_request.path);
    test::eq(request.host, der_request.host);
    test::eq(request.http_version, der_request.http_version);
    test::eq(request.body, der_request.body);

    // TODO: test eq for headers and extensions
}

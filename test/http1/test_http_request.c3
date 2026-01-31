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

    request.body = "{\r\n"
                   "\t\"name\": \"John Doe\"\r\n"
                   "}\r\n";

    String result = request.to_string(tmem)!!;
    test::eq(expected, result);
}

module req;

import tora;

fn void test_ok_0() @test
{
    String[*] input =
    {
        "HTTP/1.1 200 OK \r\n",
        "Content-Type: application/json \r\n",
        "Content-Length: 115 \r\n",
        "Connection: keep-alive \r\n",
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n",
        "Server: nginx/1.18.0 \r\n",

        // Headers and Body separator
        CLRF,

        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}",

        CLRF_END,
    };

    Response response = get_response(&input);

    test::eq(response.version, Version.HTTP1_1.str);
    test::eq(response.status, "200");
    test::eq(response.headers.content_type, "application/json");
    test::eq(response.headers.content_length, 115);
    test::eq(response.headers.connection, "keep-alive");
    test::eq(response.headers.date, "Wed, 13 Aug 2025 12:00:00 GMT");
    test::eq(response.headers.server, "nginx/1.18.0");
    test::@check(response.body.contains("success"));
    test::@check(response.body.contains("}"));
}

fn void test_ok_1() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "Content-Type: application/json \r\n",
      "Date: Fri, 15 Aug 2025 16:59:17 GMT \r\n",
      "Vary: Accept-Encoding \r\n",
      "Via: 1.1 Caddy \r\n",
      "Transfer-Encoding: chunked \r\n",

      // Headers and Body separator
      CLRF,

      // Chunk Length
      "141\n",
      "{\n",
          "\"method\": \"GET\" \n",
          "\"protocol\": \"http\" \n",
          "\"host\": \"echo.free.beeceptor.com\" \n",
          "\"path\": \"/\" \n",
          "\"ip\": \"213.22.219.242:35126\" \n",
          "\"headers\": { \n",
          "\"Host\": \"echo.free.beeceptor.com\" \n",
          "\"User-Agent\": \"curl/8.12.1\" \n",
          "\"Accept\": \"*/*\" \n",
          "\"Via\": \"1.1 Caddy\" \n",
          "\"Accept-Encoding\": \"gzip\" \n",
       "}\n",
       "\"parsedQueryParams\": {} \n",
      CLRF_END,
    };

    // Then i'll need to figure out how to call recv(), that has incomplete
    // mock socket and then add more to the mock socket somehow

    Response res = get_response(&input);

    test::eq(res.status, "200");
    test::eq(res.version, "HTTP/1.1");
    test::eq(res.headers.transfer_encoding, CHUNKED_ENCODING);
    test::eq(res.headers.via, "1.1 Caddy");
    test::@check(res.body.contains("parsedQueryParams"));
}

fn void test_internal_error_0() @test
{
    String[*] input =
    {
        "HTTP/1.1 500 Internal Server Error \r\n",
        "Content-Type: application/json \r\n",
        "Content-Length: 68 \r\n",
        "Connection: keep-alive \r\n",
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n",
        "Server: nginx/1.18.0 \r\n",

        // Headers and Body separator
        CLRF,

        "{\"error\": \"Internal Server Error\",\"message\": \"Something went wrong\"}",

        CLRF_END
    };

    Response response = get_response(&input);

    test::eq(response.version, Version.HTTP1_1.str);
    test::eq(response.status, "500");
    test::eq(response.headers.content_type, "application/json");
    test::eq(response.headers.content_length, 68);
    test::eq(response.headers.connection, "keep-alive");
    test::eq(response.headers.date, "Wed, 13 Aug 2025 12:00:00 GMT");
    test::eq(response.headers.server, "nginx/1.18.0");
    test::@check(response.body.contains("Internal Server Error"));
    test::@check(response.body.contains("}"));
}

fn void test_headers_via() @test
{
    String[*] input =
    {
        "Header: HTTP/1.1 200 OK\r\n",
        "Access-Control-Allow-Origin: *\r\n",
        "Content-Type: application/json\r\n",
        "Date: Thu, 14 Aug 2025 10:56:43 GMT\r\n",
        "Vary: Accept-Encoding\r\n",
        "Via: 1.1 Caddy\r\n",
        "Transfer-Encoding: chunked\r\n",

        CLRF,

        "1",
        "{",

        CLRF_END,
    };

    Response response = get_response(&input);

    test::eq(response.headers.vary, "Accept-Encoding");
    test::eq(response.headers.via, "1.1 Caddy");
    test::eq(response.headers.transfer_encoding, "chunked");

}

fn void test_bad_request_0() @test
{
    String[*] input =
    {
      "HTTP/1.1 400 Bad Request \r\n",
      "Content-Type: text/plain; charset=utf-8 \r\n",
      "Content-Length: 16\r\n",
      "Connection: close \r\n",

      // Headers and Body separator
      CLRF,

      "400 Bad Request \r\n",

      CLRF_END,
    };

    Response res = get_response(&input);

    test::eq(res.version, Version.HTTP1_1.str);
    test::eq(res.status, "400");
    test::eq(res.headers.connection, "close");
    test::@check(res.headers.content_type.contains("text/plain"));
    test::@check(res.body.contains("400 Bad Request"));
}

fn void test_empty_request() @test
{
    String[*] input =
    {
      "",
    };

    Response res = get_response(&input);
    test::eq(res.version, "");
    test::eq(res.status, "");
    test::eq(res.headers.connection, "");
    test::eq(res.body, "");
}

fn Response get_response(String[] input)
{
    DString in = dstring::temp();
    foreach (&str : input) in.appendf(*str);

    MockSocket soc = { .buf = in.str_view() };

    Response res;
    res.recv(&soc)!!;

    return res;
}

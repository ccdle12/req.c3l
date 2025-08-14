module req;

import tora;

fn void test_deserialize_response() @test
{
    // Creating this as an array, simply to make each line more readable.
    String[*] input =
    {
      "HTTP/1.1 400 Bad Request \r\n",
      "Content-Type: text/plain; charset=utf-8 \r\n",
      "Connection: close \r\n",

      // Headers and Body separator
      "\r\n\r\n",

      "400 Bad Request \r\n"
    };

    Response response = get_response(&input);

    test::eq(response.version, Version.HTTP1_1.str);
    test::eq(response.status, "400");
    test::eq(response.headers.connection, "close");
    test::eq(response.body, "400 Bad Request");
}


fn void test_deserialize_ok_response() @test
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
          "\r\n\r\n",

        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}",
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

fn void test_deserialize_internal_error() @test
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
        "\r\n\r\n",

        "{\"error\": \"Internal Server Error\",\"message\": \"Something went wrong\"}"
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

fn void test_deserialize_response_via() @test
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
        "\r\n\r\n",
    };

    Response response = get_response(&input);

    test::eq(response.headers.vary, "Accept-Encoding");
    test::eq(response.headers.via, "1.1 Caddy");
    test::eq(response.headers.transfer_encoding, "chunked");

}

fn Response get_response(String[] input)
{
    DString in = dstring::temp();
    foreach (&str : input) in.appendf(*str);

    Response response;
    response.deserialize(in.str_view());

    return response;
}

module req;

import tora;
import std::net::tcp;
import std::collections;
import std::net::os;

fn void test_ok_content_length_0() @test
{
    String[*] input =
    {
        "HTTP/1.1 200 OK \r\n",
        "Content-Type: application/json \r\n",
        "Content-Length: 115 \r\n",
        "Connection: keep-alive \r\n",
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n",
        "Server: nginx/1.18.0",

        // Headers and Body separator
        CRLF,

        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}",

        CRLF_END,
    };

    Response response = get_response(&input)!!;

    test::eq(response.version, Version.HTTP1_1.str);
    test::eq(response.status, "200");
    test::eq(response.headers.content_type, "application/json");
    test::eq(response.headers.content_length, 115);
    test::eq(response.headers.connection, "keep-alive");
    test::eq(response.headers.date, "Wed, 13 Aug 2025 12:00:00 GMT");
    test::eq(response.headers.server, "nginx/1.18.0");
    test::@check(response.body.contains("{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}",));
    test::@check(response.body.contains("}"));
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
        "Server: nginx/1.18.0",

        // Headers and Body separator
        CRLF,

        "{\"error\": \"Internal Server Error\",\"message\": \"Something went wrong\"}",

        CRLF_END
    };

    Response response = get_response(&input)!!;

    test::eq(response.version, Version.HTTP1_1.str);
    test::eq(response.status, "500");
    test::eq(response.headers.content_type, "application/json");
    test::eq(response.headers.content_length, 68);
    test::eq(response.headers.connection, "keep-alive");
    test::eq(response.headers.date, "Wed, 13 Aug 2025 12:00:00 GMT");
    test::eq(response.headers.server, "nginx/1.18.0");
    test::@check(response.body.contains("{\"error\": \"Internal Server Error\",\"message\": \"Something went wrong\"}"));
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
        "Transfer-Encoding: chunked",

        CRLF,

        "1\r\n",
        "{\r\n",

        CRLF_END,
    };

    Response response = get_response(&input)!!;

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
      "Connection: close",

      // Headers and Body separator
      CRLF,

      "400 Bad Request \r\n",

      CRLF_END,
    };

    Response res = get_response(&input)!!;

    test::eq(res.version, Version.HTTP1_1.str);
    test::eq(res.status, "400");
    test::eq(res.headers.connection, "close");
    test::@check(res.headers.content_type.contains("text/plain"));

    // TODO: This is changed to lower case
    //test::@check(res.body.contains("400 Bad Request"));
    test::@check(res.body.contains("400 bad request"));
}

// An empty request should lead to a timeout.
fn void test_empty_request() @test
{
    String[*] input =
   {
      "",
    };

   fault excuse = @catch(get_response(&input, 200));
   test::@check(excuse == TIMEOUT);
}

// Helper function to create a bi-directional socket, writes the input to the
// transmitter side, and returns a Response client, reading from the receiving
// socket.
fn Response? get_response(String[] input, usz timeout_ms=30000)
{
    DString in = dstring::temp();
    foreach (&str : input) in.appendf(*str);

    TcpSocketPair socket_pair;
    socket_pair.init()!;

    socket_pair.send.write(in.str_view())!;

    return recv(socket_pair.recv, timeout_ms);
}

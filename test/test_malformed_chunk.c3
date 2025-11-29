module req;

// Passes a malformed chunk length.
fn void test_malformed_chunk_0() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "access-control-allow-origin: *\r\n",
      "content-type: application/json \r\n",
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n",
      "via: 1.1 Caddy \r\n",
      "transfer-encoding: chunked",

      // Headers and Body separator
      CRLF,

      "02\r\n",
      "{\"key\": \"value\", \"i\": 1}\r\n",
      "0\r\n",

      CRLF_END,
    };

    fault excuse = @catch(get_response(&input));
    test::@check(excuse == string::MALFORMED_INTEGER);
}

// The Chunked body doesn't contain the 0 terminated chunk size.
// The HTTPParser should block trying to read from the socket and timeout.
fn void test_malformed_chunk_1() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "access-control-allow-origin: *\r\n",
      "content-type: application/json \r\n",
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n",
      "via: 1.1 Caddy \r\n",
      "transfer-encoding: chunked",

      // Headers and Body separator
      CRLF,

      "18\r\n",
      "{\"key\": \"value\", \"i\": 1}\r\n",
    };

    fault excuse = @catch(get_response(&input, 200));
    test::@check(excuse == TIMEOUT);
}

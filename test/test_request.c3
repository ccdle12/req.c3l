module req;

import tora;

fn void test_version() @test
{
    test::eq(Version.HTTP1_1.str, "HTTP/1.1");
}

fn void test_headers() @test
{
    KVList extra_headers;
    extra_headers.tinit();

    for (int i = 0; i < 10; i++)
    {
        String key = string::tformat("KEY_%d", i);
        String value = string::tformat("VALUE_%d", i);
        extra_headers.push({key, value});
    }

    Headers headers =
    {
        .host = "foo.com",
        .user_agent = "",
        .accept = ContentType.JSON.str,
        .accept_language = Language.EN_US.str,
        .accept_encoding = AcceptEncoding.GZIP.str,
        .connection = Connection.KEEP_ALIVE.str,
        .content_type = ContentType.JSON.str,
        .content_length = 30,
        .authorization = string::tformat("%s <some-key>", Authorization.BASIC.str),
        .cookie = "some-cookies",
        .extra_headers = extra_headers
    };

    test::eq(headers.accept_language, "en-us");
    test::eq(headers.authorization, "Authorization: Basic <some-key>");
    test::eq(headers.accept_encoding, "gzip");
    test::eq(headers.extra_headers.len(), 10);

    test::eq(headers.extra_headers[0].first, "KEY_0");
    test::eq(headers.extra_headers[0].second, "VALUE_0");
    test::eq(headers.extra_headers[^1].first, "KEY_9");
    test::eq(headers.extra_headers[^1].second, "VALUE_9");
}

fn void test_request_init() @test
{
    Request request = init("/api/example", Method.GET, "foo");
    test::eq(request.version, Version.HTTP1_1.str);
}

fn void test_request_serialization() @test
{
    String[*] expected_request =
    {
      "GET /foo/bar HTTP/1.1\r\n"
      "Host: www.foo.com\r\n",
      "User-Agent: Chrome/91.0.4472.124\r\n",
      "Accept: */*\r\n",
      "Accept-Encoding: gzip\r\n",
      "Accept-Language: en-us\r\n",
      "Connection: close\r\n",
      "Content-Type: application/json\r\n",
      "Content-Length: 30\r\n",
      CRLF_SINGLE,
      "{\"msg\": \"Hello World\"}"
    };

    DString expected = dstring::temp();
    foreach (&line : expected_request)
    {
        expected.appendf(*line);
    }
    tora::debug("EXPECTED:  %s", expected.str_view());

    Headers headers =
    {
        .host = "www.foo.com",
        .user_agent = "Chrome/91.0.4472.124",
        .accept = ContentType.ANY.str,
        .accept_encoding = AcceptEncoding.GZIP.str,
        .accept_language = Language.EN_US.str,
        .connection = Connection.CLOSE.str,
        .content_type = ContentType.JSON.str,
        .content_length = 30,
    };

    Request request =
    {
        .uri = "/foo/bar",
        .method = Method.GET,
        .version = Version.HTTP1_1.str,
        .headers = headers,
        .body = "{\"msg\": \"Hello World\"}"
    };

    test::eq(request.serialize().len, expected.str_view().len);
    test::eq(request.serialize(), expected.str_view());
}

fn void test_request_without_fields() @test
{
    String[*] expected_request =
    {
      "GET / HTTP/1.1\r\n"
      "Host: echo.free.beeceptor.com\r\n",
      "User-Agent: curl/8.12.1\r\n",
      "Accept: */*\r\n",
      "Accept-Encoding: gzip\r\n",
      "Accept-Language: en-us\r\n",
      "Content-Type: application/json\r\n",
      CRLF_SINGLE,
    };

    DString expected = dstring::temp();
    foreach (&line : expected_request)
    {
        expected.appendf(*line);
    }

    Headers headers =
    {
        .host = "echo.free.beeceptor.com",
        .user_agent = "curl/8.12.1",
        .accept = ContentType.ANY.str,
        .accept_encoding = AcceptEncoding.GZIP.str,
        .accept_language = Language.EN_US.str,
        .content_type = ContentType.JSON.str,
    };

    Request request =
    {
        .uri = "/",
        .method = Method.GET,
        .version = Version.HTTP1_1.str,
        .headers = headers,
    };

    test::eq(request.serialize(), expected.str_view());
}

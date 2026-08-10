module req::http1;

import std::io;
import std::collections::set;

fn void test_no_duplicate_singleton_headers() @test
{
    HashSet{String} singletons = get_singleton_headers_set(tmem);

    HttpResponse http_response;
    http_response.init(tmem);

    // Populate the headers with all the singleton headers.
    singletons.@each(; String singleton)
    {
        http_response.parse_and_set_header(singleton, "foo")!!;
    };

    // Attempt to populate the headers again with the singletons, it should fail.
    singletons.@each(; String singleton)
    {
        test::@check(@catch(http_response.parse_and_set_header(singleton, "foo")));
    };
}

fn void test_allow_exact_duplcate_content_length() @test
{
    HttpResponse http_response;
    http_response.init(tmem);

    http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "0")!!;
    http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "0")!!;
}

fn void test_error_different_content_length() @test
{
    HttpResponse http_response;
    http_response.init(tmem);

    http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "0")!!;
    test::@check(@catch(http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "1")));
    test::@check(@catch(http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "00")));
    test::@check(@catch(http_response.parse_and_set_header(CONTENT_LENGTH_KEY, " 0")));
    test::@check(@catch(http_response.parse_and_set_header(CONTENT_LENGTH_KEY, "0 ")));
}

fn void test_response_to_string_with_multiple_headers() @test
{
    HttpResponse response;
    response.tinit();

    String expected = "HTTP/1.1 200 OK\r\n"
                      "access-control-allow-origin: *\r\n"
                      "content-type: application/json\r\n"
                      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
                      "vary: Accept-Encoding, User-Agent\r\n"
                      "via: 1.1 Caddy\r\n"
                      "\r\n";


    response.http_version = "HTTP/1.1";
    response.status_code = 200;
    response.reason_phrase = "OK";

    response.headers.push("access-control-allow-origin", "*")!!;
    response.headers.push("Content-Type", "application/json")!!;
    response.headers.push("Date", "Sat, 16 Aug 2025 21:48:49 GMT")!!;
    response.headers.push("vary", "Accept-Encoding")!!;
    response.headers.push("vary", "User-Agent")!!;
    response.headers.push("via", "1.1 Caddy")!!;

    String body = "{\r\n"
                  "\t\"name\": \"John Doe\"\r\n"
                  "}\r\n";

    response.body.appendf("%s", body);

    String result = response.to_string(tmem)!!;
    test::eq(expected, result);
}

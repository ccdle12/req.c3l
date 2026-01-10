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

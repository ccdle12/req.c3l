module req::http1;

import std::collections::set;

fn void test_setting_singleton_headers() @test
{
    get_singleton_headers_set(tmem).@each(; String singleton)
    {
        Header header;
        header.init(tmem);
        header.set_header(singleton, singleton)!!;

        test::eq(header.type, HeaderType.SINGLETON);
    };
}

fn void test_setting_special_case_headers() @test
{
    get_special_case_headers(tmem).@each(; String special_case)
    {
        Header header;
        header.init(tmem);
        header.set_header(special_case, special_case)!!;

        test::eq(header.type, HeaderType.SPECIAL_CASE);
    };
}

fn void test_header_copy() @test
{
    Header header;
    header.init(tmem);
    header.set_header("CONTENT-LENGTH", "foo")!!;

    test::eq(header.type, HeaderType.SPECIAL_CASE);
    test::eq(header.key, "content-length");
    test::eq(header.values.len(), 1);

    Header copy = header.copy(tmem);
    test::eq(header.type, copy.type);
    test::eq(header.key, copy.key);
    test::@check(header.values.equals(copy.values));

    header.push_value("bar");
    test::eq(header.values.len(), 2);
    test::@check(!header.values.equals(copy.values));
}

fn void test_set_cookie() @test
{
    HttpHeaders headers;
    headers.init(tmem);
    headers.set_cookie("NID=99=YsDT5i3E-CXax-; expires=Wed, 23-Nov-2011 01:05:03 GMT; path=/; domain=.google.ch; HttpOnly; Max-Age=3600; Secure; SameSite=Strict")!!;

    Cookie cookie = headers.cookies.get("NID")!!;
    test::eq(cookie.name, "NID");
    test::eq(cookie.value, "99=YsDT5i3E-CXax-");
    test::eq(cookie.path, "/");
    test::eq(cookie.domain, ".google.ch");
    test::eq(cookie.http_only, true);
    test::eq(cookie.max_age, 3600);
    test::eq(cookie.secure, true);
    test::eq(cookie.same_site, SameSite.STRICT);

    // Replace and update the cookie, should update the entry and clear.
    headers.set_cookie("NID=foo;")!!;
    Cookie updated_cookie = headers.cookies.get("NID")!!;
    test::eq(updated_cookie.name, "NID");
    test::eq(updated_cookie.value, "foo");
    test::eq(updated_cookie.path, "");
    test::eq(updated_cookie.domain, "");
    test::eq(updated_cookie.http_only, false);
    test::eq(updated_cookie.max_age, 0);
    test::eq(updated_cookie.secure, false);
    test::eq(updated_cookie.same_site, SameSite.LAX);
}

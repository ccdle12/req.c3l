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

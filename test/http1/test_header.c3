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

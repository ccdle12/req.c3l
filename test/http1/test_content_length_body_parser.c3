module req::http1;

import std::io;

<*
  A test helper to setup the ParserTestFixture using the ContentLengthBodyParser for
  each test.
*>
macro void? @run_content_length_body_parser_test(String input, ulong content_length_num; @test_asserts(ParserTestFixture* fixture))
{
    ContentLengthBodyParser parser;
    parser.init();

    ParserTestFixture fixture;
    fixture.init(&parser);

    DString value;
    value.tinit();
    value.appendf("%d", content_length_num);

    fixture.response.headers.set(CONTENT_LENGTH, value.str_view());

    fixture.parse(input)!!;
    @test_asserts(&fixture);
}

//// Test for RFC compliance. ////

fn void test_content_length_body_0() @test
{
    ulong content_length = 20;
    String input = "Line1\r\nLine2\r\nX     ";

    @run_content_length_body_parser_test(input, content_length; ParserTestFixture* fixture)
    {
        test::eq(fixture.result, HttpParserResult.COMPLETE);
        test::@check(fixture.response.body.str_view().contains(input));
    }!!;
}

fn void test_content_length_body_1() @test
{
    ulong content_length = 36;
    String input = "Hello\r\nThis is a\r\nmulti-line body123";

    @run_content_length_body_parser_test(input, content_length; ParserTestFixture* fixture)
    {
        test::eq(fixture.result, HttpParserResult.COMPLETE);
        test::@check(fixture.response.body.str_view().contains(input));
    }!!;
}

fn void test_content_length_incremental_read() @test
{
    ulong content_length = 36;
    String input_0 = "Hello";

    @run_content_length_body_parser_test(input_0, content_length; ParserTestFixture* fixture)
    {
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
        test::@check(fixture.response.body.str_view().contains(input_0));

        String input_1 = "\r\nThis";
        test::eq(fixture.parse(input_1)!!, HttpParserResult.REQUEST_MORE);
        test::@check(fixture.response.body.str_view().contains(input_1));

        String input_2 = " is a\r\n";
        test::eq(fixture.parse(input_2)!!, HttpParserResult.REQUEST_MORE);
        test::@check(fixture.response.body.str_view().contains(input_2));

        String input_3 = "multi-line";
        test::eq(fixture.parse(input_3)!!, HttpParserResult.REQUEST_MORE);
        test::@check(fixture.response.body.str_view().contains(input_3));

        String input_4 = " body123";
        test::eq(fixture.parse(input_4)!!, HttpParserResult.COMPLETE);
        test::@check(fixture.response.body.str_view().contains(input_4));
    }!!;

}

fn void test_content_length_0_body() @test
{
    ulong content_length = 0;
    String input = "foo";

    @run_content_length_body_parser_test(input, content_length; ParserTestFixture* fixture)
    {
        test::eq(fixture.result, HttpParserResult.COMPLETE);
        test::@check(!fixture.response.body.str_view().contains(input));
    }!!;
}

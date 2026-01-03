module req::http1;

import std::io;

<*
  A test helper to setup the ParserTestFixture using the HeaderParser for
  each test.
*>
macro void? @run_header_parser_fixture(String input; @test_asserts(ParserTestFixture* fixture))
{
    HeaderParser parser;
    parser.init(tmem);

    @run_parser_test_fixture(input, &parser; ParserTestFixture* fixture)
    {
        @test_asserts(fixture);
    }!;
}

fn fault assert_header_parser_error(String input)
{
    return @catch(@run_header_parser_fixture(input; ParserTestFixture* fixture){});
}

//// Test for RFC compliance. ////

fn void test_invalid_header_key_symbols() @test
{
    String[] invalid_headers = {
        "Connetion>: \r\n",  // Invalid character '>'
        "???: \r\n",         // Invalid character '?'
        "Content?Type: \r\n", // Invalid character '?'
        "Connec@ion: \r\n",   // Invalid character '@'
        "Connec[ion: \r\n",   // Invalid character '['
        "Connec]ion: \r\n",   // Invalid character ']'
        "Connection{: \r\n",   // Invalid character '{'
        "Connection}: \r\n"   // Invalid character '}'
        "Connection -Type: \r\n"   // Invalid character ' '
    };

    foreach (&header : invalid_headers)
    {
        test::eq(assert_header_parser_error(*header), INVALID_HEADER_KEY_SYMBOL);
    }
}

fn void test_invalid_whitespace_in_header() @test
{
    String input = "Content-Type : \r\n";
    test::eq(assert_header_parser_error(input), INVALID_TRAILING_SPACE);
}

module req::http1;

import std::io;

<*
  The test function for header parser, it updates the fixture.
*>
fn HttpParserResult? header_parse_step(ParserTestFixture* fixture, String input)
{
    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    HeaderParser* parser = (HeaderParser*) fixture.parser;

    while (try byte = buf.read_byte())
    {
        fixture.result = parser.@step(byte, &fixture.response)!;
    }

    return fixture.result;
}

fn fault assert_header_parser_error(String input)
{
    HeaderParser parser;
    parser.init(tmem);

    return @catch(@run_parser_test_fixture(input, parser, &header_parse_step; ParserTestFixture* fixture){});
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

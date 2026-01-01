module req;

import std::io;

macro void? @header_parser_test(String input; @test_asserts(Response response, HeaderParser parser, ParserResult result))
{
    HeaderParser parser;
    parser.init(tmem);

    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    Response response;
    response.tinit();

    ParserResult result;
    while (buf.read_idx < buf.write_idx)
    {
        char current = buf.read_byte()!;
        result = parser.step(current, &response)!;
    }
    @test_asserts(response, parser, result);
}

fn fault header_parser_error_test(String input)
{
    return @catch(@header_parser_test(input; Response response, HeaderParser parser, ParserResult result){});
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
        test::eq(header_parser_error_test(*header), INVALID_HEADER_KEY_SYMBOL);
    }
}

fn void test_invalid_whitespace_in_header() @test
{
    String input = "Content-Type : \r\n";
    test::eq(header_parser_error_test(input), INVALID_TRAILING_SPACE);
}

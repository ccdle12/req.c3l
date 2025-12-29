module req;

import std::io;

macro void? @header_parser_test(String input; @test_asserts(Response response, HeaderParser parser, HeaderState state))
{
   HeaderParser parser;
   parser.init(tmem);

   io::ByteBuffer buf;
   buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
   buf.write(input)!;

   Response response;
   response.tinit();

   HeaderState state = parser.step(&buf, &response)!;
   @test_asserts(response, parser, state);
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
        fault excuse = @catch(@header_parser_test(*header; Response response, HeaderParser parser, HeaderState state){});
        test::eq(excuse, INVALID_HEADER_KEY_SYMBOL);
    }
}

fn void test_invalid_whitespace_in_header() @test
{
    String input = "Content-Type : \r\n";
    fault excuse = @catch(@header_parser_test(input; Response response, HeaderParser parser, HeaderState state){});
    test::eq(excuse, INVALID_TRAILING_SPACE);
}

module req::http1;

import std::io;

<*
  A test helper to setup the ParserTestFixture using the ChunkBodyParser for
  each test.
*>
macro void? @run_chunk_body_parser_test(String input; @test_asserts(ParserTestFixture* fixture, ChunkBodyParser* body_parser))
{
    ChunkBodyParser parser;
    parser.init(tmem);

    @run_parser_test_fixture(input, &parser; ParserTestFixture* fixture)
    {
        @test_asserts(fixture, &parser);
    }!;
}

//// Test for RFC compliance. ////

fn void test_chunk_body_hex_num() @test
{
    String input = "4\r\n";
    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
        test::eq(parser.chunk_size, 4);
        test::eq(parser.state, ChunkBodyParserState.READ_CHUNK);
    }!!;
}

fn void test_chunk_delayed_lf() @test
{
    String input =
        "4\r\n"
        "Wiki\r";

    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
        test::eq(parser.state, ChunkBodyParserState.CHUNK_LF);

        String final_input = "\n";
        test::eq(fixture.parse(final_input)!!, HttpParserResult.REQUEST_MORE);

        // The chunk should now be written in the response body.
        test::@check(fixture.response.body.str_view().contains("Wiki"));

        // The parser should now be ready for the next hex num.
        test::eq(parser.state, ChunkBodyParserState.HEX_NUM);
    }!!;
}

fn void test_zero_hex_and_double_crlf() @test
{
    // We've read the 0 bytes, but we haven't received the double crlf yet.
    String input =
        "4\r\n"
        "Wiki\r\n"
        "0\r\n";

    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        test::eq(fixture.result, HttpParserResult.REQUEST_MORE);
        test::eq(parser.state, ChunkBodyParserState.EXTENSION);

        String final_input = "\r\n";
        test::eq(fixture.parse(final_input)!!, HttpParserResult.COMPLETE);
        test::eq(parser.state, ChunkBodyParserState.COMPLETE);
    }!!;
}

fn void test_multiple_body_chunks() @test
{
    // We've read the 0 bytes, but we haven't received the double crlf yet.
    String input =
        "4\r\n"
        "Wiki\r\n"
        "5\r\n"
        "pedia\r\n"
        "E\r\n"
        " in\r\n"
        "\r\n"
        "chunks.\r\n";

    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        test::@check(fixture.response.body.str_view().contains("Wiki"));
        test::@check(fixture.response.body.str_view().contains("pedia"));
        test::@check(fixture.response.body.str_view().contains(" in\r\n\r\nchunks."));
        test::eq(parser.state, ChunkBodyParserState.HEX_NUM);

        String final_input =
            "0\r\n"
            "\r\n";
        test::eq(fixture.parse(final_input)!!, HttpParserResult.COMPLETE);
        test::eq(parser.state, ChunkBodyParserState.COMPLETE);
    }!!;
}

//// Test for errors. ////

// Test that extra bytes after the final double crlf doesn't result in an endless
// loop.
fn void test_bytes_after_double_crlf() @test
{
    String input =
        "4\r\n"
        "Wiki\r\n"
        "0\r\n"
        "\r\n"
        "extra bytes";

    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        test::eq(fixture.result, HttpParserResult.COMPLETE);
        test::@check(fixture.response.body.str_view().contains("Wiki"));
    }!!;
}

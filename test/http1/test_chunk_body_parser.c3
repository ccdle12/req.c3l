module req::http1;

import std::io;
import std::collections;

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
        test::eq(parser.state, ChunkBodyParserState.DOUBLE_CR);

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

fn void test_chunk_body_extensions() @test
{

    String input =
        "4;ext1=val1;flag\r\n"
        "Wiki\r\n"
        "5;ext2=\"a;quoted\"value\";ext4=42\r\n"
        "pedia\r\n"
        "3;something;ext5=100fox;another;something2;ext6=bar;ext7=@!#$DSF\r\n"
        "foo";

    @run_chunk_body_parser_test(input; ParserTestFixture* fixture, ChunkBodyParser* parser)
    {
        HashMap{String, String}* map = &fixture.response.extensions;

        test::@check(*map.get_ref("ext1")!! == "val1");
        test::@check(*map.get_ref("flag")!! == "flag");
        test::@check(*map.get_ref("ext2")!! == "\"a");
        test::@check(*map.get_ref("quoted\"value\"")!! == "quoted\"value\"");
        test::@check(*map.get_ref("ext4")!! == "42");
        test::@check(*map.get_ref("something")!! == "something");
        test::@check(*map.get_ref("ext5")!! == "100fox");
        test::@check(*map.get_ref("another")!! == "another");
        test::@check(*map.get_ref("something2")!! == "something2");
        test::@check(*map.get_ref("ext6")!! == "bar");
        test::@check(*map.get_ref("ext7")!! == "@!#$DSF");

        test::@check(fixture.response.body.str_view().contains("Wiki"));
        test::@check(fixture.response.body.str_view().contains("pedia"));
        test::@check(fixture.response.body.str_view().contains("foo"));
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

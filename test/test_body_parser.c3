module req;

import std::io;

macro void? @body_parser_test(String input; @test_asserts(io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result))
{
    BodyParser parser;
    parser.init(tmem);

    io::ByteBuffer buf;
    buf.tinit(MAX_SIZE, INITIAL_CAPACITY);
    buf.write(input)!;

    Response response;
    response.tinit();

    ParserResult result;
    while (try current = buf.read_byte())
    {
        result = parser.step(current, &response)!;
    }
    @test_asserts(&buf, &response, &parser, &result);
}

//// Test for RFC compliance. ////

fn void test_chunk_body_hex_num() @test
{
    String input = "4\r\n";

    (void)@body_parser_test(input; io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result)
    {
        test::eq(*result, ParserResult.REQUEST_MORE);
        test::eq(parser.chunk_size, 4);
        test::eq(parser.state, BodyParserState.READ_CHUNK);
    };
}

fn void test_chunk_delayed_lf() @test
{
    String input =
        "4\r\n"
        "Wiki\r";

    (void)@body_parser_test(input; io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result)
    {
        test::eq(*result, ParserResult.REQUEST_MORE);
        test::eq(parser.state, BodyParserState.CHUNK_LF);

        String final_input = "\n";
        buf.write(final_input)!!;

        ParserResult result_1;
        while (try current = buf.read_byte())
        {
            result_1 = parser.step(current, response)!!;
        }
        test::eq(result_1, ParserResult.REQUEST_MORE);

        // The chunk should now be written in the response body.
        test::@check(response.body.str_view().contains("Wiki"));

        // The parser should now be ready for the next hex num.
        test::eq(parser.state, BodyParserState.HEX_NUM);
    };
}

fn void test_zero_hex_and_double_crlf() @test
{
    // We've read the 0 bytes, but we haven't received the double crlf yet.
    String input =
        "4\r\n"
        "Wiki\r\n"
        "0\r\n";

    (void)@body_parser_test(input; io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result)
    {
        test::eq(*result, ParserResult.REQUEST_MORE);
        test::eq(parser.state, BodyParserState.EXTENSION);

        String final_input = "\r\n";
        buf.write(final_input)!!;

        while (buf.read_idx < buf.write_idx)
        {
            char current = buf.read_byte()!!;
            (void)parser.step(current, response)!!;
        }

        test::eq(parser.state, BodyParserState.COMPLETE);
    };
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

    (void)@body_parser_test(input; io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result)
    {
        test::@check(response.body.str_view().contains("Wiki"));
        test::@check(response.body.str_view().contains("pedia"));
        test::@check(response.body.str_view().contains(" in\r\n\r\nchunks."));
        test::eq(parser.state, BodyParserState.HEX_NUM);

        String final_input =
            "0\r\n"
            "\r\n";
        buf.write(final_input)!!;

        //while (buf.read_idx < buf.write_idx) parser.step(buf, response)!!;
        while (buf.read_idx < buf.write_idx)
        {
            char current = buf.read_byte()!!;
            (void)parser.step(current, response)!!;
        }
        test::eq(parser.state, BodyParserState.COMPLETE);
    };
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

    (void)@body_parser_test(input; io::ByteBuffer* buf, Response* response, BodyParser* parser, ParserResult* result)
    {
        test::eq(*result, ParserResult.COMPLETE);
        test::@check(response.body.str_view().contains("Wiki"));
    };
}

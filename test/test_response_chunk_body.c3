module req;

import std::io;

fn void test_chunk_body_read_0() @test
{
    String input = "4\r\n";

    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    ParserState result = parser.step(input)!!;

    test::eq(result, ParserState.REQUEST_MORE);
    test::eq(parser.body_parser.chunk_size_read, 4);
    test::eq(parser.body_parser.state, BodyParserState.READ_CHUNK);
}

fn void test_chunk_body_read_1() @test
{
    String input =
        "4\r\n"
        "Wiki\r\n";

    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    ParserState result = parser.step(input)!!;

    test::eq(result, ParserState.REQUEST_MORE);
    test::@check(parser.response.body.str_view().contains("Wiki"));
    test::eq(parser.body_parser.state, BodyParserState.READ_HEX_NUM);
}

fn void test_chunk_body_read_2() @test
{
    String input_0 =
        "4\r\n"
        "Wiki\r";

    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    ParserState result = parser.step(input_0)!!;

    test::eq(result, ParserState.REQUEST_MORE);

    // TODO: It shouldn't be trying to read hex num at this point, its just REQUEST_MORE
    test::eq(parser.body_parser.state, BodyParserState.AFTER_CHUNK_LF);

    String input_1 = "\n";
    test::eq(parser.step(input_1)!!, ParserState.REQUEST_MORE);

    // The chunk should now be written.
    test::@check(parser.response.body.str_view().contains("Wiki"));

    // The parser should now be ready for the next hex num.
    test::eq(parser.body_parser.state, BodyParserState.READ_HEX_NUM);
}

fn void test_chunk_body_read_3() @test
{
    // We've read the 0 bytes, but we haven't received the double crlf yet.
    String input_0 =
        "4\r\n"
        "Wiki\r\n"
        "0\r\n";

    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    ParserState result = parser.step(input_0)!!;

    test::eq(result, ParserState.REQUEST_MORE);
    test::eq(parser.body_parser.state, BodyParserState.EXTENSION);

    //THIS SHOULD BE COMPLETE BECAUSE OF THE FINAL DOUBLE CRLF
    String input_1 =
        "\r\n";

    test::eq(parser.step(input_1)!!, ParserState.COMPLETE);
}

fn void test_multiple_body_chunks() @test
{
    // ANY bytes after the chunk size should be counted as bytes that should be
    // read, even if they are crlf.
    String input_0 =
        "4\r\n"
        "Wiki\r\n"
        "5\r\n"
        "pedia\r\n"
        "E\r\n"
        " in\r\n"
        "\r\n"
        "chunks.\r\n";

    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    test::eq(parser.step(input_0)!!, ParserState.REQUEST_MORE);

    test::@check(parser.response.body.str_view().contains("Wiki"));
    test::@check(parser.response.body.str_view().contains("pedia"));
    test::@check(parser.response.body.str_view().contains(" in\r\n\r\nchunks."));
    test::eq(parser.body_parser.state, BodyParserState.READ_HEX_NUM);

    String input_1 =
        "0\r\n"
        "\r\n";

    test::eq(parser.step(input_1)!!, ParserState.COMPLETE);
    io::printfn("body in test: %s", parser.response.body.str_view());
}

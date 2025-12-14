module req;

fn void test_chunk_body_read_0() @test
{
    String input =
        "4\r\n";


    Parser parser;
    parser.tinit();

    parser.response.body_type = BodyType.CHUNKED;
    parser.state = ParserState.BODY;

    ParserState state = parser.step(input)!!;
    test::eq(state, ParserState.REQUEST_MORE);
    test::eq(parser.body_state, ParserState.READ_HEX_NUM);

    test::eq(parser.chunk_size_read, 4);

    // TODO: Should return REQUEST_MORE.
    // TODO: I guess response.body should have this so far?
}

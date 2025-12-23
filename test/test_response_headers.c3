module req;

<*
 Helper test function to feed invalid header lines.
*>
fn void test_invalid_header(String input, fault expected_error)
{
    Response response;
    response.tinit();

    fault excuse = @catch(response.parse_header(input));
    test::eq(excuse, expected_error);
}

fn void test_invalid_header_key_symbols() @test
{
    String[] invalid_headers = {
        "Connetion>",  // Invalid character '>'
        "???",         // Invalid character '?'
        "Content?Type", // Invalid character '?'
        "Connec@ion",   // Invalid character '@'
        "Connec[ion",   // Invalid character '['
        "Connec]ion",   // Invalid character ']'
        "Connection{",   // Invalid character '{'
        "Connection}"   // Invalid character '}'
        "Connection -Type"   // Invalid character ' '
    };

    foreach (&header : invalid_headers) test_invalid_header(*header, INVALID_HEADER_KEY_SYMBOL);
}

fn void test_invalid_whitespace_in_header() @test
{

    String input = "Content-Type ";
    test_invalid_header(input, INVALID_TRAILING_SPACE);
}

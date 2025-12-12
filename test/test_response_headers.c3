module req;

import std::collections::map;
import tora;

<*
 Helper test function to feed invalid header lines.
*>
fn void test_invalid_header(String input, fault expected_error)
{
    Response response;
    response.tinit();

    fault excuse = @catch(response.parse_header_line(input));
    test::eq(excuse, expected_error);
}

fn void test_invalid_header_key_symbols() @test
{
    String[] invalid_headers = {
        "Connetion>: keep-alive",  // Invalid character '>'
        "???: keep-alive",         // Invalid character '?'
        "Content?Type: application/json", // Invalid character '?'
        "Connec@ion: keep-alive",   // Invalid character '@'
        "Connec[ion: keep-alive",   // Invalid character '['
        "Connec]ion: keep-alive",   // Invalid character ']'
        "Connection{: keep-alive",   // Invalid character '{'
        "Connection}: keep-alive"   // Invalid character '}'
    };

    foreach (&header : invalid_headers) test_invalid_header(*header, INVALID_HEADER_KEY_SYMBOL);
}

fn void test_invalid_whitespace_in_header() @test
{

    String input = "Content-Type : application/json \r\n";
    test_invalid_header(input, INVALID_TRAILING_SPACE);
}

fn void test_invalid_line_termination()
{
    String input = "Content-Type: application/json \n\r";
    test_invalid_header(input, MALFORMED_HEADER);
}

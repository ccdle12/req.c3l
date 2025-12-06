module req;

import std::collections::map;
import tora;

fn void test_headers_without_crlf() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0";

   Response response;
   response.tinit();

   fault excuse = @catch(response.parse_header(input));
   test::eq(excuse, MISSING_CRLF);
}

// TODO: 2025.12.03 - Right now, this fails correctly but doesn't actually
// identify that a malformed header was received due to missing \r\n
fn void test_missing_new_lines() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT"
        "Server: nginx/1.18.0"
        "\r\n\r\n";

   Response response;
   response.tinit();

   fault excuse = @catch(response.parse_header(input));
   test::eq(excuse, MALFORMED_HEADER);
}

fn void test_headers() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0"
        "\r\n\r\n"
        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}"
        "0\r\n\r\n";

   Response response;
   response.tinit();
   response.parse_header(input)!!;

   test::eq(response.get_header("Content-Type")!!, "application/json");
   test::eq(response.get_header("Connection")!!, "keep-alive");
   test::eq(response.get_header("Date")!!, "Wed, 13 Aug 2025 12:00:00 GMT");
   test::eq(response.get_header("Server")!!, "nginx/1.18.0");
   test::eq(response.body_type, BodyType.CONTENT_LENGTH);
}

// RFC 9112, Section 6.1: Message Body Length
// If transfer-encoding and content-length are missing, then the message is still
// valid but the body length is assumed to be 0.
fn void test_no_body_type() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0"
        "\r\n\r\n"
        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}"
        "0\r\n\r\n";

   Response response;
   response.tinit();

   test::eq(response.body_type, BodyType.NULL);
}

// According to RFC9112 6.1:
// There is a priortiy rule that emphasizes that Transfer-Encoding has precedence
// over Content-Length.
//
// TODO: 2025.12.03 - according to the RFC, the server MUST close the connection
// after sending the response after receiving both Transfer-Encoding AND Content-Length
// due to mitigating "Request Smuggling" attacks.
fn void test_transfer_encoding_priority() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \r\n"
        "Content-Length: 115 \r\n"
        "Connection: keep-alive \r\n"
        "Date: Wed, 13 Aug 2025 12:00:00 GMT \r\n"
        "Server: nginx/1.18.0 \r\n"
        "transfer-encoding: chunked"
        "\r\n\r\n"
        "{\"status\": \"success\", \"data\": {\"id\": 123,\"name\": \"Test Item\",\"value\": 42},\"message\": \"Item retrieved successfully\"}"
        "0\r\n\r\n";

   Response response;
   response.tinit();

   fault excuse = @catch(response.parse_header(input));
   test::eq(response.body_type, BodyType.CHUNKED);
}

fn void test_invalid_header(String invalid_header_line)
{
    String input = string::format(
                     tmem,
                     "HTTP/1.1 200 OK \r\n"
                     "Content-Type: application/json \r\n"
                     "%s"
                     "\r\n\r\n",
                     invalid_header_line
                   );

    Response response;
    response.tinit();

    fault excuse = @catch(response.parse_header(input));
    test::eq(excuse, INVALID_HEADER_KEY_SYMBOL);
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

    foreach (&header : invalid_headers)
    {
        test_invalid_header(*header);
    }
}

fn void test_invalid_whitespace_in_header() @test
{

    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type : application/json \r\n"
        "\r\n\r\n";

    Response response;
    response.tinit();

    fault excuse = @catch(response.parse_header(input));
    test::eq(excuse, INVALID_WHITE_SPACE_IN_HEADER);
}

fn void test_invalid_line_termination() @test
{
    String input =
        "HTTP/1.1 200 OK \r\n"
        "Content-Type: application/json \n"
        "\r\n\r\n";

    Response response;
    response.tinit();

    fault excuse = @catch(response.parse_header(input));
    test::eq(excuse, INVALID_WHITE_SPACE_IN_HEADER);
}

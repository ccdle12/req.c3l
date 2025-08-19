module req;

import std::net::url;
import std::net::tcp;
import std::io;
import tora;

faultdef FAIL_SEND, FAIL_READ, ZERO_BYTES_READ;

fn Response? recv(InStream socket)
{
    Response response;

    HTTPParser parser;
    parser.init(socket);

    parser.read_headers(&response)!;
    parser.read_body(&response)!;

    return response;
}

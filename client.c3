module req;

import std::net::url;
import std::net::tcp;
import std::io;
import tora;

faultdef FAIL_SEND, ZERO_BYTES_READ;

fn Response? recv(TcpSocket socket)
{
    Response response;

    HTTPParser parser;
    parser.init(socket);

    parser.read_headers(&response)!;
    parser.read_body(&response)!;

    return response;
}

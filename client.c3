module req;

import std::net::tcp;

faultdef FAIL_SEND, ZERO_BYTES_READ;

fn Response? recv(TcpSocket socket, usz timeout_ms=30000)
{
    Response response;

    HTTPParser parser;
    parser.init(socket, tmem, timeout_ms);

    parser.read_headers(&response)!;
    parser.read_body(&response)!;

    return response;
}

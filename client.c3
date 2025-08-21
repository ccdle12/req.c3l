module req;

import std::net::tcp;

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

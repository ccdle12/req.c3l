module req;

import std::net::tcp;

faultdef FAIL_SEND, ZERO_BYTES_READ;

fn Response? recv_tinit(TcpSocket socket, usz timeout_ms=30000) => recv(socket, tmem, timeout_ms);

fn Response? recv(TcpSocket socket, Allocator allocator=tmem, usz timeout_ms=30000)
{
    Response response;

    HTTPParser parser;
    parser.init(socket, allocator, timeout_ms)!;
    defer parser.free();

    parser.read_headers(&response)!;
    parser.read_body(&response)!;

    return response;
}

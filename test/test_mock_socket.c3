module req;

import tora;
import std::io;

struct MockSocket (InStream)
{
    char[] buf;
}

fn usz? MockSocket.read(&self, char[] buffer) @dynamic
{
    mem::copy(buffer, self.buf, self.buf.len);
    return self.buf.len;
}

fn char? MockSocket.read_byte(&self) @dynamic
{
    return self.buf[0];
}

// TODO: Come back to this as a long term ticket
fn void test_missing_clrf() @test
{
    // Creating this as an array, simply to make each line more readable.
    String[*] input =
    {
      "HTTP/1.1 400 Bad Request \r\n",
      "Content-Type: text/plain; charset=utf-8 \r\n",
      "Content-Length: 16\r\n",
      "Connection: close \r\n",
    };

    //Response res = get_response(&input);

    //test::eq(res.version, Version.HTTP1_1.str);
    //test::eq(res.status, "400");
    //test::eq(res.headers.connection, "close");
    //test::@check(res.headers.content_type.contains("text/plain"));
}

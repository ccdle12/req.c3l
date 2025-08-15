module req;

import std::net;
import std::io;
import libc;
import tora;

struct Response
{
    String version;
    String status;
    String body;
    Headers headers;
}

fn void Response.read_headers(&self, char[] headers)
{
    String[] split_headers = ((String) headers).tsplit("\r\n");
    String[] status = split_headers[0].tsplit(" ");

    self.version = status[0];
    self.status = status[1];

    foreach (&line : split_headers[1..])
    {
        // Split into two halves on the first occurence of `:`
        String[] kv = line.tsplit(":", 2);

        String key = kv[0];
        key.convert_to_lower();

        if (CONTENT_TYPE == key)
        {
            self.headers.content_type = kv[1].trim();
        }

        if (DATE == key)
        {
            self.headers.date = kv[1].trim();
        }

        if (VIA == key)
        {
            self.headers.via = kv[1].trim();
        }

        if (VARY == key)
        {
            self.headers.vary = kv[1].trim();
        }

        if (SERVER == key)
        {
            self.headers.server = kv[1].trim();
        }

        if (CONTENT_LENGTH == key)
        {
            // TODO: Handle the unwrap
            self.headers.content_length = kv[1].trim().to_uint()!!;
        }

        if (CONNECTION == key)
        {
            self.headers.connection = kv[1].trim();
        }

        if (TRANSFER_ENCODING == key)
        {
            self.headers.transfer_encoding = kv[1].trim();
        }
    }
}

fn String Response.str_view(&self)
{

    DString res = dstring::temp();
    res.appendf("%s ", self.version);
    res.appendf("%s\r\n", self.status);

    if (self.headers.host.len > 0)
    {
        res.appendf("Host: %s\r\n", self.headers.host);
    }

    if (self.headers.user_agent.len > 0)
    {
        res.appendf("User-Agent: %s\r\n", self.headers.user_agent);
    }

    if (self.headers.content_length > 0)
    {
        res.appendf("Content-Length: %s\r\n", self.headers.content_length);
    }

    res.appendf("Content-Type: %s\r\n", self.headers.content_type);

    if (self.headers.connection.len > 0)
    {
        res.appendf("Connection: %s\r\n", self.headers.connection);
    }

    res.appendf("Date: %s\r\n", self.headers.date);

    if (self.headers.server.len > 0)
    {
        res.appendf("Server: %s\r\n", self.headers.server);
    }

    res.appendf("Vary: %s\r\n", self.headers.vary);
    res.appendf("Via: %s\r\n", self.headers.via);
    res.appendf("Transfer-Encoding: %s\r\n", self.headers.transfer_encoding);

    res.appendf("\r\n\r\n");

    if (self.body.len > 0)
    {
        res.appendf("Body: %s\r\n", self.body);
    }

    return res.str_view();
}

//TODO:
// 1. If there is a content-length header, ready the body according to this size
// - The problem is:
// - The body might have whitespace

// 2. If Transfer-Encoding header is set to chunked, we need to parse the body as
//    an individual chunk
//fn void? Response.recv(&self, TcpSocket* socket)
fn void? Response.recv(&self, InStream socket)
{
    char[4096] buf;

    // 13. Content Length: Maybe from the split, do the same thing [clrf+4:content-length]
    // 14. Content Length: Check if the slice is less than content-length, if so, call recv(), if its the same or more then just parse
    usz bytes_read;

    bool headers_parsed;
    while (!headers_parsed || bytes_read > 4096)
    {
        tora::debug("header loop");
        bytes_read += socket.read(buf[bytes_read..])!;
        // MAYBE THIS SHOULD BE A FAILED READ?
        if (bytes_read == 0) return;

        String read_bytes = (String) buf[0..bytes_read];

        // TODO: This is a DDOS vector
        if (!read_bytes.contains(CLRF)) continue;

        self.read_headers(&read_bytes.tsplit(CLRF)[0]);
        headers_parsed = true;
    }

    usz clrf_idx = ((String) &buf).index_of(CLRF)!! + 4;

    if (self.headers.transfer_encoding == CHUNKED_ENCODING)
    {
        String body_bytes = (String) buf[clrf_idx..];

        if (!body_bytes.contains(CLRF_END))
        {
            bool body_parsed;
            while (!body_parsed || bytes_read > 4096)
            {
                usz bytes_len = socket.read(buf[bytes_read..])!;
                if (bytes_len == 0)
                {
                    body_parsed = true;
                    break;
                }

                bytes_read += bytes_len;

                // TODO: I think this should be checking from clrf_idx since thats the point.
                // It's this point until the end looking for CLRF_END.
                String read_bytes = (String) buf[clrf_idx..];
                tora::debug("CHUNK read_bytes: %s", read_bytes);

                // TODO: DDOS vector
                if (read_bytes.contains(CLRF_END)) body_parsed = true;
            }
        }

        ulong chunk_size = libc::strtol(buf[clrf_idx:3], null, 16);
        ulong chunk_offset = clrf_idx+3;

        self.read_chunked_body(&buf, chunk_offset, chunk_size);

        tora::debug("self: \n%s", self.to_str());
    }
}

fn void Response.read_chunked_body(&self, char[] buf, ulong chunk_offset, ulong chunk_size)
{
    char[4092] body_buf;
    ulong body_idx;
    ulong body_end_idx = chunk_offset + chunk_size;

    for (ulong i = chunk_offset; i < body_end_idx; i++)
    {
        body_buf[body_idx] = buf[i];
        body_idx++;
    }

    self.body = (String) body_buf[..body_idx];
}

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

    if (self.headers.date.len > 0)
    {
        res.appendf("Date: %s\r\n", self.headers.date);
    }

    if (self.headers.server.len > 0)
    {
        res.appendf("Server: %s\r\n", self.headers.server);
    }

    if (self.headers.vary.len > 0)
    {
        res.appendf("Vary: %s\r\n", self.headers.vary);
    }

    if (self.headers.via.len > 0)
    {
        res.appendf("Via: %s\r\n", self.headers.via);
    }

    if (self.headers.transfer_encoding.len > 0)
    {
        res.appendf("Transfer-Encoding: %s\r\n", self.headers.transfer_encoding);
    }

    res.appendf(CRLF);

    if (self.body.len > 0)
    {
        res.appendf("Body: %s\r\n", self.body);
    }

    return res.str_view();
}

fn usz? Response.append_buf(&self, DString* dyn_buf, InStream socket)
{
    char[4096] buf;

    usz bytes_read = socket.read(&buf)!;

    // TODO: MAYBE THIS SHOULD BE A FAILED READ?
    //if (bytes_read == 0) return;

    // TODO: bytes_read can never be greater than in_buf len?
    dyn_buf.append_chars((String) buf[..bytes_read]);

    return bytes_read;

}

// TODO: Maybe this should be on client, Response probably shuoldn't know about the socket.
fn void? Response.recv(&self, InStream socket)
{
    DString dyn_buf = dstring::temp();

    while (!contains_crlf(&dyn_buf))
    {
        usz? bytes_read = self.append_buf(&dyn_buf, socket)!;
        if (try bytes_read)
        {
            if (bytes_read == 0) return;
        }
    }

    self.read_headers(dyn_buf.str_view());

    usz clrf_idx = find_end_of_crlf(&dyn_buf)!;

    if (self.headers.content_length > 0)
    {
        if (clrf_idx + self.headers.content_length > dyn_buf.len())
        {
            usz? bytes_read = self.append_buf(&dyn_buf, socket)!;
            if (try bytes_read)
            {
                if (bytes_read == 0) return;
            }
        }

        // TODO: Safety, Need to check if clrf_idx and self.headers.content_lenght is less than dyn_buf?
        String view = dyn_buf.str_view();
        self.body = view[clrf_idx:self.headers.content_length];
    }

    if (self.headers.transfer_encoding == CHUNKED_ENCODING)
    {
        DString chunk_buf = dstring::temp();
        usz chunk_offset = clrf_idx;

        while (true)
        {
            // TODO: Figure out this split safely
            String view = dyn_buf.str_view();
            String[] chunk_split = view[chunk_offset..].tsplit("\r\n");

            usz chunk_byte_len = chunk_split[0].len;
            ulong? chunk_size = chunk_split[0].to_uint(base: 16);

            if (try chunk_size)
            {
                if (chunk_size == 0) break;

                // TODO: Scary
                while (clrf_idx + chunk_size > dyn_buf.len())
                {
                    usz? bytes_read = self.append_buf(&dyn_buf, socket)!;
                    if (try bytes_read)
                    {
                        if (bytes_read == 0) return;
                    }

                }

                chunk_offset = clrf_idx + chunk_byte_len;
                chunk_buf.append_chars(view[chunk_offset:chunk_size]);
            }
            else
            {
                break;
            }
        }

        self.body = chunk_buf.str_view();
        tora::debug("response: \n%s", self.str_view());
    }
}

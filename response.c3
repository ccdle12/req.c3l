module req;

import std::net;
import std::io;
import std::collections;
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

    res.appendf(CLRF);

    if (self.body.len > 0)
    {
        res.appendf("Body: %s\r\n", self.body);
    }

    return res.str_view();
}

fn void? Response.recv(&self, InStream socket)
{
    List{char} dyn_buf;
    dyn_buf.tinit();
    usz bytes_read;
    char[4096] buf;

    CRLFState state = START;
    while (state != END)
    {
        tora::debug("header loop");
        bytes_read += socket.read(&buf)!;
        // MAYBE THIS SHOULD BE A FAILED READ?
        if (bytes_read == 0) return;

        // TODO: Maybe this loop should be up to bytes_read.
        //foreach (&c : buf) dyn_buf.push(*c);
        for (usz i = 0; i < bytes_read; i++)
        {
            dyn_buf.push(buf[i]);
        }

        // TODO: DDOS vector we need a timeout
        state = step_state_machine(&dyn_buf);
    }

    self.read_headers(dyn_buf.array_view());

    // TODO: Its a hack but need to account for new line after CLRF
    // I got make this more clear and to check.
    // It's inclusive of the last char, thats why I added the plus one.
    // Maybe I should make this more clear in the docs.
    usz clrf_idx = step_state_machine_with_index(&dyn_buf) + 1;

    CRLFBodyState body_state = ZERO;
    while (body_state != END)
    {
        CRLF_Body_Result result = step_crlf_body(&dyn_buf);
        body_state = result.second;

        if (body_state == END) break;

        char[4096] in_buf;
        usz body_bytes_read = socket.read(&in_buf)!;
        for (usz i = 0; i < body_bytes_read; i++)
        {
            dyn_buf.push(buf[i]);
        }
    }

    if (self.headers.transfer_encoding == CHUNKED_ENCODING)
    {
        // NOTE: THIS IS JUST GETTING CHUNK SIZE
        char[8192] tmp;

        usz j = 0;
        for (usz i = clrf_idx; i < dyn_buf.len(); i++)
        {
            if (dyn_buf[i] == '\n') break;
            tmp[j] = dyn_buf[i];
            j++;
        }

        ulong chunk_size = libc::strtol(tmp[..j], null, 16);

        // NOTE: This is reading from dynamic buffer to filtered by chunk size.
        char[8192] filtered;
        usz pointer = clrf_idx+j;
        usz i = 0;
        tora::debug("chunk_size: %s", chunk_size);
        while(i < chunk_size)
        {
            if (dyn_buf[pointer] == '\r' || dyn_buf[pointer] == '\n')
            {
                pointer++;
                continue;
            }

            filtered[i] = dyn_buf[pointer];
            i++;
            pointer++;
        }

        tora::debug("filtered: \n%s", (String) &filtered);

        self.body = (String) &filtered;

    }

    if (self.headers.content_length > 0)
    {
        // TODO: There was some error, needs to be handled better.
        if (self.headers.content_length > dyn_buf.len()) return;

        char[] view = dyn_buf.array_view();
        self.body = (String) view[clrf_idx:self.headers.content_length];
    }

    tora::debug("self: \n%s", self.str_view());
}

module req;

import std::net::tcp;
import tora;

// TODO: Is there a way I can make this NOT InStream socket but make it a comptime where its either Socket or InStream?
struct HTTPParser
{
    DString dyn_buf;
    TcpSocket socket;
}

fn void HTTPParser.init(&self, TcpSocket socket)
{
    self.dyn_buf = dstring::temp();
    self.socket = socket;
}


fn void? HTTPParser.read_headers(&self, Response* response)
{
    while (!contains_crlf(&self.dyn_buf))
    {
        if (self.append_buf()! == 0) return ZERO_BYTES_READ?;
    }

    response.deserialize_headers(self.dyn_buf.str_view());
}

fn String HTTPParser.str_view(&self) => self.dyn_buf.str_view() @inline;

fn void? HTTPParser.read_body(&self, Response* response)
{
    switch(response.body_type)
    {
        case NONE:
            // TODO: NEED TO HANDLE THIS AS A FAILED PARSE
            return ZERO_BYTES_READ?;
        case CONTENT_LENGTH:
            self.read_content_length_body(response)!;
        case CHUNKED:
            self.read_chunked_body(response)!;
    }
}

fn void? HTTPParser.read_content_length_body(&self, Response* response) @inline @private
{
    usz clrf_idx = find_end_of_crlf(&self.dyn_buf)!;

    if (clrf_idx + response.headers.content_length > self.dyn_buf.len())
    {
        if (self.append_buf()! == 0) return;
    }

    // TODO: Safety, Need to check if clrf_idx and self.headers.content_lenght is less than dyn_buf?
    String view = self.dyn_buf.str_view();
    response.body = view[clrf_idx:response.headers.content_length];
}

fn void? HTTPParser.read_chunked_body(&self, Response* response) @inline @private
{
    usz clrf_idx = find_end_of_crlf(&self.dyn_buf)!;

    DString chunk_buf = dstring::temp();
    usz chunk_offset = clrf_idx;

    while (true)
    {
        // TODO: Figure out this split safely
        String view = self.dyn_buf.str_view();
        String[] chunk_split = view[chunk_offset..].tsplit("\r\n");

        usz chunk_byte_len = chunk_split[0].len;
        ulong? chunk_size = chunk_split[0].to_uint(base: 16);

        // TODO: Think through if this is the right thing to do. If we are
        // unable to read the next chunk size, just return.
        if (catch excuse = chunk_size) break;
        if (chunk_size == 0) break;

        // TODO: Scary
        while (clrf_idx + chunk_size > self.dyn_buf.len())
        {
            usz? bytes_read = self.append_buf()!;
            if (try bytes_read)
            {
                if (bytes_read == 0) return;
            }

        }

        chunk_offset = clrf_idx + chunk_byte_len;
        chunk_buf.append_chars(view[chunk_offset:chunk_size]);
    }

    response.body = chunk_buf.str_view();
    tora::debug("response: \n%s", response.str_view());

}

fn usz? HTTPParser.append_buf(&self) @private
{
    char[4096] buf;
    usz bytes_read = self.socket.read(&buf)!;

    // TODO: MAYBE THIS SHOULD BE A FAILED READ?
    //if (bytes_read == 0) return;

    // TODO: bytes_read can never be greater than in_buf len?
    self.dyn_buf.append_chars((String) buf[..bytes_read]);

    return bytes_read;

}

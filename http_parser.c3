module req;

import std::net::tcp;
import tora;

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
        if (self.read_sock_to_buf()! == 0) return ZERO_BYTES_READ?;
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
        if (self.read_sock_to_buf()! == 0) return;
    }

    // TODO: Safety, Need to check if clrf_idx and self.headers.content_lenght is less than dyn_buf?
    String view = self.dyn_buf.str_view();
    response.body = view[clrf_idx:response.headers.content_length];
}

fn void? HTTPParser.read_chunked_body(&self, Response* response) @inline @private
{
    usz current_offset = find_end_of_crlf(&self.dyn_buf)!;
    usz crlf_size = 2;
    DString chunk_buf = dstring::temp();

    bool end_chunk_found = false;

    while (current_offset < self.dyn_buf.len())
    {
        // TODO: Create a test to test this with a malformed &self.dyn_buf
        DString chunk_size_str = dstring::temp();
        while (current_offset < self.dyn_buf.len() && self.dyn_buf[current_offset] != '\r')
        {
            chunk_size_str.append_char(self.dyn_buf[current_offset]);
            current_offset += 1;
        }

        ulong? chunk_size = chunk_size_str.str_view().to_uint(base: 16);
        // TODO: Return errors instead of just breaking
        if (catch excuse = chunk_size) break;
        if (chunk_size == 0) break;

        current_offset += crlf_size;

        usz i = 0;
        while (current_offset + i < self.dyn_buf.len() && i < chunk_size)
        {
            char current = self.dyn_buf[current_offset + i];
            chunk_buf.append_char(current);
            if (current != '\r' || current != '\n') i += 1;
        }

        current_offset += chunk_size + crlf_size;
    }

    response.body = chunk_buf.str_view();
}

fn usz? HTTPParser.read_sock_to_buf(&self) @private
{
    char[4096] buf;
    usz bytes_read = self.socket.read(&buf)!;

    // TODO: MAYBE THIS SHOULD BE A FAILED READ?
    //if (bytes_read == 0) return;

    // TODO: bytes_read can never be greater than in_buf len?
    self.dyn_buf.append_chars((String) buf[..bytes_read]);

    return bytes_read;

}

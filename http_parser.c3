module req;

import std::net::tcp;
import std::net;

faultdef TIMEOUT;

struct HTTPParser
{
    Allocator allocator;
    TcpSocket socket;
    usz poll_ms_timeout;
    Poll[1] polls;
    DString dyn_buf;
}

fn void? HTTPParser.init(&self, TcpSocket socket, Allocator allocator=tmem, usz timeout_ms=30000)
{
    self.allocator = allocator;
    self.socket = socket;

    self.socket.sock.set_non_blocking(true)!;
    Poll sock_poll = { .events = net::PollSubscribe.ANY_READ, .socket = self.socket.sock };
    Poll[1] polls = { sock_poll };
    self.polls = polls;
    self.poll_ms_timeout = timeout_ms;

    // TODO: 2025.11.29
    // - Allocate dyn_buf using the allocator passed
    // - Create a function to free the dyn_buf
    self.dyn_buf.init(self.allocator);
}

fn void HTTPParser.free(&self)
{
    self.dyn_buf.free();
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
    DString chunk_buf;
    chunk_buf.init(self.allocator);
    defer chunk_buf.free();

    usz current_offset = find_end_of_crlf(&self.dyn_buf)!;

    while (true)
    {
        ulong? chunk_size = self.read_chunk_size(&current_offset);
        if (catch excuse = chunk_size)
        {
            // We have a malformed chunk. This fails because we are expecting
            // to read a chunk size str.
            if (current_offset < self.dyn_buf.len()) return excuse?;

            // We reached the end of the current dyn_buf, the malformed char
            // could indicate we are missing more chunks, read from the socket
            // to see if there is more of the body available to read.
            self.read_sock_to_buf()!;

            continue;
        }

        if (chunk_size == 0) break;

        self.read_sub_chunk(&chunk_buf, &current_offset, chunk_size);
    }

    response.body = chunk_buf.str_view();
}

fn ulong? HTTPParser.read_chunk_size(&self, usz* current_offset) @private
{
    DString chunk_size_str;
    chunk_size_str.init(self.allocator);
    defer chunk_size_str.free();

    while (*current_offset < self.dyn_buf.len() && self.dyn_buf[*current_offset] != '\r')
    {
        chunk_size_str.append_char(self.dyn_buf[*current_offset]);
        *current_offset += 1;
    }

    return chunk_size_str.str_view().to_uint(base: 16);
}

fn void HTTPParser.read_sub_chunk(&self, DString* chunk_buf, usz* current_offset, ulong chunk_size) @private
{
    usz crlf_size = 2;

    *current_offset += crlf_size;

    // Read bytes from the buf by chunk size.
    usz i = 0;
    while (*current_offset + i < self.dyn_buf.len() && i < chunk_size)
    {
        char current = self.dyn_buf[*current_offset + i];
        chunk_buf.append_char(current);
        if (current != '\r' || current != '\n') i += 1;
    }

    *current_offset += chunk_size + crlf_size;
}

fn usz? HTTPParser.read_sock_to_buf(&self) @private
{
    char[4096] buf;

    ulong poll_res = net::poll_ms(&self.polls, self.poll_ms_timeout)!;
    if (poll_res == 0) return TIMEOUT?;

    usz bytes_read = self.socket.read(&buf)!;
    if (bytes_read == 0) return ZERO_BYTES_READ?;

    // TODO: bytes_read can never be greater than in_buf len?
    self.dyn_buf.append_chars((String) buf[..bytes_read]);

    return bytes_read;
}

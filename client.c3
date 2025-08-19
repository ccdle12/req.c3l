module req;

import std::net::url;
import std::net::tcp;
import std::io;
import tora;

faultdef FAIL_SEND, FAIL_READ, ZERO_BYTES_READ;

fn uint scheme_to_port(String scheme) @private
{
    scheme.convert_to_lower();

    if (scheme == "http")
    {
            return 80;
    }

    // TODO: We will assume an https connection
    return 443;
}

fn Response? recv(InStream socket) @private
{
    Response response;
    DString dyn_buf = dstring::temp();

    read_headers(&dyn_buf, socket)!;
    response.deserialize_headers(dyn_buf.str_view());

    switch(response.body_type)
    {
        case NONE:
            // TODO: NEED TO HANDLE THIS AS A FAILED PARSE
            return ZERO_BYTES_READ?;
        case CONTENT_LENGTH:
            read_content_length_body(&response, &dyn_buf, socket)!;
        case CHUNKED:
            read_chunked_body(&response, &dyn_buf, socket)!;
    }

    return response;
}

fn void? read_headers(DString* dyn_buf, InStream socket) @inline @private
{
    while (!contains_crlf(dyn_buf))
    {
        usz bytes_read = append_buf(dyn_buf, socket)!;
        if (bytes_read == 0) return ZERO_BYTES_READ?;
    }
}

fn void? read_content_length_body(Response* response, DString* dyn_buf, InStream socket) @inline @private
{
    usz clrf_idx = find_end_of_crlf(dyn_buf)!;

    if (clrf_idx + response.headers.content_length > dyn_buf.len())
    {
        usz bytes_read = append_buf(dyn_buf, socket)!;
        if (bytes_read == 0) return;
    }

    // TODO: Safety, Need to check if clrf_idx and self.headers.content_lenght is less than dyn_buf?
    String view = dyn_buf.str_view();
    response.body = view[clrf_idx:response.headers.content_length];
}

fn void? read_chunked_body(Response* response, DString* dyn_buf, InStream socket) @inline @private
{
    usz clrf_idx = find_end_of_crlf(dyn_buf)!;

    DString chunk_buf = dstring::temp();
    usz chunk_offset = clrf_idx;

    while (true)
    {
        // TODO: Figure out this split safely
        String view = dyn_buf.str_view();
        String[] chunk_split = view[chunk_offset..].tsplit("\r\n");

        usz chunk_byte_len = chunk_split[0].len;
        ulong? chunk_size = chunk_split[0].to_uint(base: 16);

        // TODO: Think through if this is the right thing to do. If we are
        // unable to read the next chunk size, just return.
        if (catch excuse = chunk_size) break;
        if (chunk_size == 0) break;

        // TODO: Scary
        while (clrf_idx + chunk_size > dyn_buf.len())
        {
            usz? bytes_read = append_buf(dyn_buf, socket)!;
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

fn usz? append_buf(DString* dyn_buf, InStream socket) @private
{
    char[4096] buf;
    usz bytes_read = socket.read(&buf)!;

    // TODO: MAYBE THIS SHOULD BE A FAILED READ?
    //if (bytes_read == 0) return;

    // TODO: bytes_read can never be greater than in_buf len?
    dyn_buf.append_chars((String) buf[..bytes_read]);

    return bytes_read;

}

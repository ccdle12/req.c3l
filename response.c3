module req;

import std::net;
import libc;
import tora;

struct Response
{
    String version;
    String status;
    String body;
    Headers headers;
}


// TODO: Maybe there is a more effective way to do this.

//TODO:
// 1. If there is a content-length header, ready the body according to this size
// - The problem is:
// - The body might have whitespace

// 2. If Transfer-Encoding header is set to chunked, we need to parse the body as
//    an individual chunk
fn void Response.deserialize(&self, char[] buf)
{
    DString header = dstring::temp();
    DString body = dstring::temp();

    bool end_of_headers;
    foreach (&byte : buf)
    {
        if (end_of_headers)
        {
            body.write_byte(*byte)!!;
        }
        else
        {
            header.write_byte(*byte)!!;
        }

        // TODO: What if \r\n\r\n doesn't appear?
        if (!end_of_headers && header.str_view().ends_with("\r\n\r\n"))
        {
            end_of_headers = true;
        }
    }
    self.body = body.str_view().trim();

    // DEBUG PRINT FOR MAIN
    tora::debug("Header: %s", header);
    tora::debug("Body: %s", body);

    String[] split_headers = header.str_view().tsplit("\r\n");
    String[] status = split_headers[0].tsplit(" ");

    self.version = status[0];
    self.status = status[1];

    foreach (&line : split_headers[1..])
    {
        // Split into two halves on the first occurence of `:`
        String[] kv = line.tsplit(":", 2);

        String key = kv[0];
        key.convert_to_lower();

        if ("content-type" == key)
        {
            self.headers.content_type = kv[1].trim();
        }

        if ("date" == key)
        {
            self.headers.date = kv[1].trim();
        }

        if ("via" == key)
        {
            self.headers.via = kv[1].trim();
        }

        if ("vary" == key)
        {
            self.headers.vary = kv[1].trim();
        }

        if ("server" == key)
        {
            self.headers.server = kv[1].trim();
        }

        if ("content-length" == key)
        {
            self.headers.content_length = (usz) kv[1].to_uint()!!;
        }

        if ("connection" == key)
        {
            self.headers.connection = kv[1].trim();
        }
    }
}

fn void Response.read_headers(&self, String *headers)
{
    String[] split_headers = headers.tsplit("\r\n");
    String[] status = split_headers[0].tsplit(" ");

    self.version = status[0];
    self.status = status[1];

    foreach (&line : split_headers[1..])
    {
        // Split into two halves on the first occurence of `:`
        String[] kv = line.tsplit(":", 2);

        String key = kv[0];
        key.convert_to_lower();

        if ("content-type" == key)
        {
            self.headers.content_type = kv[1].trim();
        }

        if ("date" == key)
        {
            self.headers.date = kv[1].trim();
        }

        if ("via" == key)
        {
            self.headers.via = kv[1].trim();
        }

        if ("vary" == key)
        {
            self.headers.vary = kv[1].trim();
        }

        if ("server" == key)
        {
            self.headers.server = kv[1].trim();
        }

        if ("content-type" == key)
        {
            self.headers.content_type = kv[1].trim();
        }

        if ("content-length" == key)
        {
            self.headers.content_length = libc::atoi(kv[1]);
        }

        if ("connection" == key)
        {
            self.headers.connection = kv[1].trim();
        }

        if ("transfer-encoding" == key)
        {
            self.headers.transfer_encoding = kv[1].trim();
        }
    }
}

fn String Response.to_str(&self)
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

fn void? Response.recv(&self, TcpSocket* socket)
{
    char[4096] buf;

    // TODO LATEST: I think this should be the plan:
    // 1. Read into buf
    // 2. Cast buf to String and check for CLRF
    // 3. If no CLRF, continue
    // 4. If CLRF found split and process headers
    // 5. Record the number of bytes read so far and the idx+4 of CLRF
    // 6. Check the headers content type and length:
    //  - Is it chunking?
    //  - Is it content length?
    // 7. Create a slice into the buf from clrf+4 to end
    // 8. Chunking: Read [clrf+4:3] to get the ASCII numberical representation and cast to int
    // 9. Chunking: Slice again [clrf+7:chunk_size] (+7 now includes the CLRF offset and the chunk size offset)
    // 10. Chunking: Check if the slice contains the termination character "0\r\n\r\n"?
    // 11. Chunking: If termination character exists in slice, then slice again [clrf+7:chunk_size] or minus "0\r\n\r\n"
    // 12. Chunking: If doesn't contain, then call recv() in a loop until chunk termination appears.
    // 13. Content Length: Maybe from the split, do the same thing [clrf+4:content-length]
    // 14. Content Length: Check if the slice is less than content-length, if so, call recv(), if its the same or more then just parse
    bool headers_parsed;
    usz header_bytes_read;
    usz clrf_idx;

    while (!headers_parsed || header_bytes_read > 4096)
    {
        header_bytes_read += socket.read(buf[header_bytes_read..])!;
        // MAYBE THIS SHOULD BE A FAILED READ?
        if (header_bytes_read == 0) return;

        String buffer = (String) buf[0..header_bytes_read];

        // TODO:
        // 1. check if we have the headers and body separator?
        // - What to do if we don't have it or just throw an error? it should be big enough to fit?

        // TODO: This is a DDOS vector
        if (!buffer.contains(CLRF)) continue;

        clrf_idx = buffer.index_of(CLRF)!!;

        // 2. Split the buffer by the separator and process header
        String[] split_packet = buffer.tsplit(CLRF);
        self.read_headers(&split_packet[0]);

        headers_parsed = true;
    }

    // NOTE: Kind of crazy
    // 1. offset the clrf_idx by 4 since its the end of `\r\n\r\n`
    usz clrf_offset = clrf_idx+4;

    if ("chunked" == self.headers.transfer_encoding)
    {
        String body_tmp = (String) buf[clrf_offset..];

        // TODO: Check if the buffer contains the termination, if not recv()
        if (!body_tmp.contains(CLRF_END))
        {
            bool body_parsed;
            while (!body_parsed || header_bytes_read > 4096)
            {
                header_bytes_read += socket.read(buf[header_bytes_read..])!;
                String bf = (String) &buf;

                if (body_tmp.contains(CLRF_END))
                {
                    body_parsed = true;
                    break;
                }
            }
        }

        usz chunk_size = (usz) libc::strtol(buf[clrf_offset:3], null, 16);
        usz clrf_chunk_offset = clrf_offset+3;

        char[4092] body_buf;
        usz body_idx;
        for (usz i = clrf_chunk_offset; i < clrf_chunk_offset+chunk_size; i++)
        {
            body_buf[body_idx] = buf[i];
            body_idx++;
        }

        tora::debug("SLICING body_buf: %s", (String) body_buf[..chunk_size]);
    }// if

}

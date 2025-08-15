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

    }
}

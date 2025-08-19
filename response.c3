module req;

import tora;

struct Response
{
    String version;
    String status;
    String body;
    Headers headers;
    BodyType body_type;
}

fn void Response.deserialize_headers(&self, char[] headers)
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

    self.set_body_parse_state();
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

enum BodyType
{
    NONE,
    CONTENT_LENGTH,
    CHUNKED,
}

fn void Response.set_body_parse_state(&self)
{
    if (self.headers.transfer_encoding == CHUNKED_ENCODING)
    {
        self.body_type = CHUNKED;
        return;
    }

    if (self.headers.content_length > 0)
    {
        self.body_type = CONTENT_LENGTH;
        return;
    }

    self.body_type = NONE;
    return;
}

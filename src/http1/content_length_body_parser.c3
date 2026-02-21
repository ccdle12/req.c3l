module req::http1;

enum ContentLengthBodyParserState
{
    READ_CONTENT,
    COMPLETE,
}

struct ContentLengthBodyParser
{
    ulong content_length_read;
    ContentLengthBodyParserState state;
}

fn void ContentLengthBodyParser.init(&self)
{
    self.content_length_read = 0;
    self.state = READ_CONTENT;
}

macro HttpParserResult? ContentLengthBodyParser.@step(&self, char byte, http_request_or_response)
{
    $assert($defined(http_request_or_response.content_length));
    $assert($defined(http_request_or_response.append_to_body));

    if (http_request_or_response.content_length == 0) return COMPLETE;

    switch(self.state)
    {
        case READ_CONTENT:
            if (self.content_length_read < http_request_or_response.content_length)
            {
                http_request_or_response.append_to_body(byte);
                self.content_length_read++;

                if (self.content_length_read == http_request_or_response.content_length)
                {
                    self.state = COMPLETE;
                    return COMPLETE;
                }
            }

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

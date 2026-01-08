module req::http1;

enum ContentLengthBodyParserState
{
    READ_CONTENT,
    COMPLETE,
}

struct ContentLengthBodyParser (HttpStepParser)
{
    ulong content_length_read;
    ContentLengthBodyParserState state;
}

fn void ContentLengthBodyParser.init(&self)
{
    self.content_length_read = 0;
    self.state = READ_CONTENT;
}

fn HttpParserResult? ContentLengthBodyParser.step(&self, char byte, HttpResponse* http_response) @dynamic
{
    if (try content_length = http_response.get_content_length())
    {
        if (content_length == 0) return COMPLETE;

        switch(self.state)
        {
            case READ_CONTENT:
                if (self.content_length_read < content_length)
                {
                    http_response.append_to_body(byte);
                    self.content_length_read++;

                    if (self.content_length_read == content_length)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }
                }

            case COMPLETE: return COMPLETE;
        }
    }
    else
    {
        return COMPLETE;
    }

    return REQUEST_MORE;
}

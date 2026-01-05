module req::http1;

import std::io;

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

fn HttpParserResult? ContentLengthBodyParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    if (try content_length = response.get_content_length())
    {
        if (content_length == 0) return COMPLETE;

        switch(self.state)
        {
            case READ_CONTENT:
                if (self.content_length_read < content_length)
                {
                    response.body.append_char(byte);
                    self.content_length_read++;

                    if (self.content_length_read == content_length)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }
                }

                break;

            case COMPLETE: return COMPLETE;
        }
    }
    else
    {
        return COMPLETE;
    }

    return REQUEST_MORE;
}

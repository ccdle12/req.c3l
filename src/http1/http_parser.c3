module req::http1;

import std::io;

const usz MAX_SIZE = 4096;
const usz INITIAL_CAPACITY = 4096;
const usz CRLF_OFFSET = 2;

faultdef MALFORMED_CRLF;

interface HttpStepParser
{
    fn HttpParserResult? step(char byte, HttpResponse* response);
}

enum HttpParserState
{
    STATUS_LINE,
    HEADER,
    BODY,
    COMPLETE,
}

enum HttpParserResult
{
    REQUEST_MORE,
    COMPLETE,
}

struct HttpParser
{
    Allocator allocator;
    io::ByteBuffer buf;
    HttpParserState state;
    StatusLineParser status_line_parser;
    HeaderParser header_parser;
    BodyParser body_parser;
}

fn void HttpParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.status_line_parser.init(self.allocator);
    self.header_parser.init(self.allocator);
    self.body_parser.init(self.allocator);

    self.state = STATUS_LINE;
}

fn void HttpParser.tinit(&self) => self.init(tmem);

fn void HttpParser.free(&self)
{
   self.buf.free();
   self.status_line_parser.free();
   self.header_parser.free();
   self.body_parser.free();
}

fn HttpParserResult? HttpParser.step(&self, char[] input, HttpResponse* response)
{
    if (input.len == 0) return REQUEST_MORE;
    self.buf.write(input)!;

    while (try byte = self.buf.read_byte())
    {
        switch (self.state)
        {
            case STATUS_LINE:
                HttpParserResult status_line = self.status_line_parser.step(byte, response)!;
                if (status_line == COMPLETE)
                {
                    self.state = HEADER;
                }
                break;

            case HEADER:
                HttpParserResult header = self.header_parser.step(byte, response)!;
                if (header == COMPLETE)
                {
                    self.state = BODY;

                    if (response.body_type == NULL)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }

                    if (response.body_type == CONTENT_LENGTH && response.content_length == 0)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }
                }

                break;

            case BODY:
                HttpParserResult body = self.body_parser.step(byte, response)!;
                if (body == COMPLETE) return COMPLETE;
                break;

            case COMPLETE: return COMPLETE;
        }
    }

    return REQUEST_MORE;
}

fn String HttpParser.buf_str_view(&self) => (String) self.buf.bytes;

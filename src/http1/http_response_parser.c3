module req::http1;

import std::io;

const usz MAX_SIZE = 4096;
const usz INITIAL_CAPACITY = 4096;
const usz CRLF_OFFSET = 2;

interface HttpResponseStepParser
{
    fn HttpParserResult? step(char byte, HttpResponse* http_response);
}

enum HttpResponseParserState
{
    STATUS_LINE,
    HEADER,
    BODY,
    COMPLETE,
}

struct HttpResponseParser
{
    Allocator allocator;
    io::ByteBuffer buf;
    HttpResponseParserState state;
    StatusLineParser status_line_parser;
    HeaderParser header_parser;
    BodyParser body_parser;
}

fn void HttpResponseParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.status_line_parser.init(self.allocator);
    self.header_parser.init(self.allocator);
    self.body_parser.init(self.allocator);

    self.state = STATUS_LINE;
}

fn void HttpResponseParser.tinit(&self) => self.init(tmem);

fn void HttpResponseParser.free(&self)
{
   self.buf.free();
   self.status_line_parser.free();
   self.header_parser.free();
   self.body_parser.free();
}

fn HttpParserResult? HttpResponseParser.step(&self, char[] input, HttpResponse* http_response)
{
    if (input.len == 0) return REQUEST_MORE;
    self.buf.write(input)!;

    while (try byte = self.buf.read_byte())
    {
        switch (self.state)
        {
            case STATUS_LINE:
                HttpParserResult status_line = self.status_line_parser.step(byte, http_response)!;
                if (status_line == COMPLETE) self.state = HEADER;

            case HEADER:
                HttpParserResult header = self.header_parser.@step(byte, http_response)!;
                if (header == COMPLETE)
                {
                    self.state = BODY;

                    if (http_response.body_type == NULL)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }

                    if (http_response.body_type == CONTENT_LENGTH && http_response.content_length == 0)
                    {
                        self.state = COMPLETE;
                        return COMPLETE;
                    }
                }

            case BODY:
                HttpParserResult body = self.body_parser.step(byte, http_response)!;
                if (body == COMPLETE) return COMPLETE;

            case COMPLETE: return COMPLETE;
        }
    }

    return REQUEST_MORE;
}

fn String HttpResponseParser.buf_str_view(&self) => (String) self.buf.bytes;

module req::http1;

import std::io;

enum HttpRequestParserState
{
    REQUEST_LINE,
    HEADER,
    BODY,
    COMPLETE,
}

struct HttpRequestParser
{
    Allocator allocator;
    io::ByteBuffer buf;
    HttpRequestParserState state;
    RequestLineParser request_line_parser;
    HeaderParser header_parser;
    BodyParser body_parser;
}

fn void HttpRequestParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.request_line_parser.init(self.allocator);
    self.header_parser.init(self.allocator);
    self.body_parser.init(self.allocator);

    self.state = REQUEST_LINE;
}

fn void HttpRequestParser.tinit(&self) => self.init(tmem);

fn void HttpRequestParser.free(&self)
{
   self.buf.free();
   self.request_line_parser.free();
   self.header_parser.free();
   self.body_parser.free();
}

fn HttpParserResult? HttpRequestParser.step(&self, char[] input, HttpRequest* http_request)
{
    if (input.len == 0) return REQUEST_MORE;
    self.buf.write(input)!;

    while (try byte = self.buf.read_byte())
    {
        switch (self.state)
        {
            case REQUEST_LINE:
                HttpParserResult request_line = self.request_line_parser.step(byte, http_request)!;
                if (request_line == COMPLETE) self.state = HEADER;

            case HEADER:
                io::printfn("in header");
                HttpParserResult header = self.header_parser.@step(byte, http_request)!;
                if (header == COMPLETE)
                {
                    self.state = COMPLETE;
                    return COMPLETE;
                }

            default: return COMPLETE;
        }
    }

    return REQUEST_MORE;
}

module req;

import std::io;

const usz MAX_SIZE = 4096;
const usz INITIAL_CAPACITY = 4096;
const usz CRLF_OFFSET = 2;

faultdef MALFORMED_CRLF;

enum ParserState
{
    STATUS_LINE,
    HEADER,
    BODY,
    COMPLETE,
    REQUEST_MORE,
}

struct Parser
{
    Allocator allocator;
    io::ByteBuffer buf;
    ParserState state;
    Response response;
    StatusLineParser status_line_parser;
    HeaderParser header_parser;
    BodyParser body_parser;
}

fn void Parser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);

    self.response.init(self.allocator);
    self.status_line_parser.init(self.allocator);
    self.header_parser.init(self.allocator);
    self.body_parser.init(self.allocator);

    self.state = STATUS_LINE;
}

fn void Parser.tinit(&self) => self.init(tmem);

fn void Parser.free(&self)
{
   self.buf.free();
   self.response.free();

   self.status_line_parser.free();
   self.header_parser.free();
   self.body_parser.free();
}

fn ParserState? Parser.step(&self, char[] input)
{
    if (input.len == 0) return REQUEST_MORE;
    self.buf.write(input)!;

    while (self.buf.read_idx < self.buf.write_idx)
    {
        switch (self.state)
        {
            case STATUS_LINE:
                StatusLineState result = self.status_line_parser.step(&self.buf, &self.response)!;
                if (result == COMPLETE) self.state = HEADER;
                break;
            case HEADER:
                HeaderState result = self.header_parser.step(&self.buf, &self.response)!;
                if (result == COMPLETE)
                {
                    if (self.response.body_type == NULL)
                    {
                        self.state = COMPLETE;
                        return self.state;
                    }

                    self.state = BODY;
                    break;
                }

                if (result == EOF) return REQUEST_MORE;

                break;
            case BODY:
                BodyParserState result = self.body_parser.step(&self.buf, &self.response)!;
                if (result == COMPLETE) return COMPLETE;
                break;
            case COMPLETE:
                return COMPLETE;
            default:
                break;
        }
    }

    return REQUEST_MORE;
}

fn String Parser.buf_str_view(&self) => (String) self.buf.bytes;

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
    HEADER_READ,
    HEADER_PROGRESS,
    BODY,
    COMPLETE,
    REQUEST_MORE,
    EOF,


    // header states
    HEADER_KEY,
    HEADER_VALUE,
    AFTER_HEADER_CR,
    AFTER_HEADER_LF,
    HEADER_COMPLETE,
    DOUBLE_CR,
    DOUBLE_LF,

}

struct Parser
{
    Allocator allocator;
    ParserState state;
    io::ByteBuffer buf;
    ParserMode mode;
    Response response;

    StatusLineParser status_line_parser;
    HeaderParser header_parser;
    BodyParser body_parser;

    // Maybe move to a header parser
    DString tmp_header;
    DString tmp_header_val;
}

enum ParserMode
{
    STATUS_LINE,
    HEADER,
    BODY,
    COMPLETE,
}

fn void Parser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);

    self.response.init(self.allocator);
    self.status_line_parser.init(self.allocator);
    self.header_parser.init(self.allocator);
    self.body_parser.init(self.allocator);

    self.mode = STATUS_LINE;
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
    if (input.len == 0) return EOF;
    self.buf.write(input)!!;

    while (self.buf.read_idx < self.buf.write_idx)
    {
        switch (self.mode)
        {
            case STATUS_LINE:
                if (self.status_line_parser.step(&self.buf.read_idx, &self.buf.write_idx, self.buf.bytes, &self.response)! == COMPLETE)
                {
                    self.mode = HEADER;
                    self.state = HEADER_KEY;
                }
                // TODO: THe same request mroe return?

                break;
            case HEADER:
                HeaderState result = self.header_parser.step(&self.buf.read_idx, &self.buf.write_idx, self.buf.bytes, &self.response)!;
                if (result == COMPLETE)
                {
                    if (self.response.body_type == NULL)
                    {
                        self.mode = COMPLETE;
                        return COMPLETE;
                    }

                    self.mode = BODY;
                    break;
                }

                if (result == EOF) return REQUEST_MORE;

                break;
            case BODY:
                // TODO: This is only a chunk body stepper.
                BodyParserState result = self.body_parser.step(&self.buf.read_idx, &self.buf.write_idx, self.buf.bytes, self.response.body)!;
                break;
            case COMPLETE:
                return COMPLETE;
        }
    }

    return REQUEST_MORE;
}

fn String Parser.buf_str_view(&self) => (String) self.buf.bytes;

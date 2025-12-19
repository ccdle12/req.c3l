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
    BodyParser body_parser;
    StatusLineParser status_line_parser;

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
    self.body_parser.init(self.allocator);
    self.status_line_parser.init(self.allocator);

    self.mode = STATUS_LINE;

    // move to header parser
    self.tmp_header.init(self.allocator);
    self.tmp_header_val.init(self.allocator);
}

fn void Parser.tinit(&self) => self.init(tmem);

fn void Parser.free(&self)
{
   self.buf.free();
   self.response.free();
   self.body_parser.free();
   self.status_line_parser.free();

   self.tmp_header.free();
   self.tmp_header_val.free();
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
                ParserState result = self.step_headers()!;
                if (result == BODY)
                {
                    if (self.response.body_type == NULL)
                    {
                        self.mode = COMPLETE;
                        return COMPLETE;
                    }

                    self.mode = BODY;
                    break;
                }

                if (result == REQUEST_MORE) return REQUEST_MORE;

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

// TODO: Maybe make these StatusLineStates?
fn ParserState? Parser.step_headers(&self)
{
    usz* read_idx = &self.buf.read_idx;
    while (self.buf.read_idx < self.buf.write_idx)
    {
        switch(self.state)
        {
        case HEADER_KEY:
            if (self.buf.bytes[*read_idx] == '\r')
            {
                self.state = DOUBLE_CR;
                break;
            }

            // TODO: Need to return error if whitespace before ':'
            if (self.buf.bytes[*read_idx] == ':')
            {
                self.state = HEADER_VALUE;
                (*read_idx)++;
                break;
            }

            self.tmp_header.append_char(self.buf.bytes[*read_idx]);
            (*read_idx)++;
            break;

        case HEADER_VALUE:
            // Catching if we hav a LF out of place, passes to the CR handler
            // to return the error.
            if (self.buf.bytes[*read_idx] == '\n')
            {
                self.state = AFTER_HEADER_CR;
                break;
            }

            if (self.buf.bytes[*read_idx] != '\r')
            {
                self.tmp_header_val.append_char(self.buf.bytes[*read_idx]);
                (*read_idx)++;
                break;
            }

            // TODO: Need to check if this memory frees correctly?
            self.response.parse_and_set_kv(self.tmp_header, self.tmp_header_val)!;

            self.tmp_header.clear();
            self.tmp_header_val.clear();

            // Set body type as it the headers arrive, we will enforce RFC 9112
            // 6.1 - Transfer Encoding has precendence over Content-Length.
            self.response.set_body_type();

            self.state = AFTER_HEADER_CR;

            break;

        case AFTER_HEADER_CR:
            if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = AFTER_HEADER_LF;
            break;

        case AFTER_HEADER_LF:
            if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = HEADER_KEY;
            break;

        case DOUBLE_CR:
            if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = HEADER_COMPLETE;
            return BODY;

        default:
            break;
        }
    }

    io::printfn("returning request more?");
    return REQUEST_MORE;
}

fn String Parser.buf_str_view(&self) => (String) self.buf.bytes;

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


    // --- tmp
    BODY_READ,
    STATUS_LINE_PROTOCOL,
    WHITESPACE,
    STATUS_LINE_STATUS_CODE,
    STATUS_LINE_CR,
    STATUS_LINE_CF,
    STATUS_LINE_REASON_SPACE,
    STATUS_LINE_REASON,

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

    // Maybe move to status parser?
    DString status_protocol_cache;
    DString status_code_cache;
    DString status_line_reason;


    // Maybe move to a header parser
    DString tmp_header;
    DString tmp_header_val;
}

enum BodyParserState
{
    READ_HEX_NUM,
    AFTER_HEX_CR,
    AFTER_HEX_LF,
    AFTER_CHUNK_CR,
    AFTER_CHUNK_LF,
    READ_CHUNK,
    READ_CHUNK_FINISHED,
    ZERO_HEX_CR,
    ZERO_HEX_LF,
    EXTENSION,
    DOUBLE_CR,
    DOUBLE_LF,
    EOF,
    COMPLETE,
}

enum ParserMode
{
    STATUS_LINE,
    HEADER,
    BODY,
    COMPLETE,
}

struct BodyParser
{
    Allocator allocator;
    BodyParserState state;
    ulong chunk_size_read;
    DString chunk_size_cache;
}

fn void BodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = READ_HEX_NUM;
    self.chunk_size_cache.init(self.allocator);
}

fn void BodyParser.free(&self)
{
    self.chunk_size_cache.free();
}

fn void Parser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.state = STATUS_LINE_PROTOCOL;
    self.response.init(self.allocator);
    self.body_parser.init(self.allocator);
    self.mode = STATUS_LINE;

    // TODO: I'll need to free this.
    self.status_protocol_cache.init(self.allocator);
    self.status_code_cache.init(self.allocator);
    self.status_line_reason.init(self.allocator);

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

   self.status_protocol_cache.free();
   self.status_code_cache.free();
   self.status_line_reason.free();
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
                if (self.step_status_line()! == HEADER)
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
                BodyParserState result = self.step_body()!;
                break;
            case COMPLETE:
                return COMPLETE;
        }
    }

    return REQUEST_MORE;
}

// TODO: Maybe make these StatusLineStates?
fn ParserState? Parser.step_status_line(&self)
{
    usz* read_idx = &self.buf.read_idx;
    while (self.buf.read_idx < self.buf.write_idx)
    {
        switch(self.state)
        {
            case STATUS_LINE_PROTOCOL:
                // @step_until(target, innercode to execute)
                if (self.buf.bytes[*read_idx] != ' ')
                {
                    self.status_protocol_cache.append_char(self.buf.bytes[*read_idx]);
                }
                else
                {
                    self.response.parse_http_protocol(self.status_protocol_cache.str_view())!;
                    self.state = STATUS_LINE_STATUS_CODE;
                }

                (*read_idx)++;
                break;

            case STATUS_LINE_STATUS_CODE:
                if (self.buf.bytes[*read_idx] != '\r' && self.buf.bytes[*read_idx] != ' ')
                {
                    self.status_code_cache.append_char(self.buf.bytes[*read_idx]);
                }
                else
                {
                    if (@catch(self.response.parse_status_code(self.status_code_cache.str_view())))
                    {
                        return INVALID_STATUS_CODE?;
                    }

                    if (self.buf.bytes[*read_idx] == '\r') self.state = STATUS_LINE_CR;
                    if (self.buf.bytes[*read_idx] == ' ') self.state = STATUS_LINE_REASON_SPACE;
                    break;
                }

                (*read_idx)++;
                break;

            case STATUS_LINE_CR:
                if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
                self.state = STATUS_LINE_CF;
                (*read_idx)++;
                break;

            case STATUS_LINE_CF:
                if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
                self.state = HEADER;
                (*read_idx)++;
                return self.state;

            case STATUS_LINE_REASON_SPACE:
                if (self.buf.bytes[*read_idx] != ' ') return MALFORMED_STATUS_LINE?;
                self.state = STATUS_LINE_REASON;
                (*read_idx)++;
                break;

            case STATUS_LINE_REASON:
                if (self.buf.bytes[*read_idx] != '\r' && self.buf.bytes[*read_idx] != ' ')
                {
                    self.status_line_reason.append_char(self.buf.bytes[*read_idx]);
                }
                else
                {
                    // TODO: Need to set a max length of this reason phrase?
                    self.response.reason_phrase = self.status_line_reason.str_view();
                    self.state = STATUS_LINE_CR;
                    break;
                }

                (*read_idx)++;
                break;

            default:
                break;
        }
    }

    return REQUEST_MORE;
}

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

// TODO: MAYBE should be step_body?, there should be some rule to identify chunk or not
fn BodyParserState? Parser.step_body(&self)
{
    usz* read_idx = &self.buf.read_idx;
    while (self.buf.read_idx < self.buf.write_idx)
    {
    switch(self.body_parser.state)
    {
        case READ_HEX_NUM:
            if (self.buf.bytes[*read_idx] != '\r')
            {
                io::printfn("Adding to chunk size hex");
                self.body_parser.chunk_size_cache.append_char(self.buf.bytes[*read_idx]);
                (*read_idx)++;
                break;
            }

            ulong chunk_size = self.body_parser.chunk_size_cache.str_view().to_uint(base: 16)!;
            self.body_parser.chunk_size_read = chunk_size;
            self.body_parser.chunk_size_cache.clear();

            if (self.body_parser.chunk_size_read == 0)
            {
                self.body_parser.state = ZERO_HEX_CR;
            }
            else
            {
                self.body_parser.state = AFTER_HEX_CR;
            }

            break;

        case AFTER_HEX_CR:
            self.body_parser.state = AFTER_HEX_LF;
            (*read_idx)++;
            break;

        case AFTER_HEX_LF:
            if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = READ_CHUNK;
            (*read_idx)++;
            break;

        case READ_CHUNK:
            if (self.body_parser.chunk_size_read > 0)
            {
                self.response.body.append_char(self.buf.bytes[*read_idx]);
                self.body_parser.chunk_size_read--;
                (*read_idx)++;
            }
            else
            {
                self.body_parser.state = AFTER_CHUNK_CR;
            }

            break;

        case AFTER_CHUNK_CR:
            if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = AFTER_CHUNK_LF;
            (*read_idx)++;
            break;

        case AFTER_CHUNK_LF:
            if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = READ_HEX_NUM;
            (*read_idx)++;
            break;

        case ZERO_HEX_CR:
            if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = ZERO_HEX_LF;
            (*read_idx)++;
            break;

        case ZERO_HEX_LF:
            if (self.buf.bytes[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = EXTENSION;
            (*read_idx)++;
            break;

        case EXTENSION:
            if (self.buf.bytes[*read_idx] == '\r') self.body_parser.state = DOUBLE_CR;
            break;

        case DOUBLE_CR:
            if (self.buf.bytes[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = DOUBLE_LF;
            (*read_idx)++;
            break;

        case DOUBLE_LF:
            if (self.buf.bytes[*read_idx] == '\n') self.body_parser.state = COMPLETE;
            break;

        case COMPLETE:
            return self.body_parser.state;

        default:
            return BodyParserState.EOF;
    }
    }

    return BodyParserState.EOF;
}

fn String Parser.buf_str_view(&self) => (String) self.buf.bytes;

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

}

struct Parser
{
    Allocator allocator;
    ParserState state;
    io::ByteBuffer buf;
    Response response;
    BodyParser body_parser;

    // Maybe move to status parser?
    DString status_protocol_cache;
    DString status_code_cache;
    DString status_line_reason;
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

    // TODO: I'll need to free this.
    self.status_protocol_cache.init(self.allocator);
    self.status_code_cache.init(self.allocator);
    self.status_line_reason.init(self.allocator);
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
}

//fn ParserState? ParserState.step_status_line_new(&self)
//{
    // TODO:
    // STATES:
    // 1. STATUS_PARSE_PROTOCOL
        // read until first white space
        // Declare the first idx
        // Increment read_idx
        // Pass (line) to response to validate
    // 2. Move to WHITESPACE
        // validate whitespace
        // increment idx
        // Move to STATUS_CODE
    // 3. STATUS_CODE
        // Read until whitespace or '\r'
        // Declare the first idx
        // Increment read_idx
        // Pass (line) to response to validate status_code
        // If whitespace, move to OPTIONAL_REASON
        // If no whitespace, move to STATUS_LINE_CR
//}


fn ParserState? Parser.step(&self, char[] input)
{
    if (input.len == 0) return EOF;
    self.buf.write(input)!!;

    usz* read_idx = &self.buf.read_idx;

    while (self.buf.read_idx < self.buf.write_idx)
    {
        switch(self.state)
        {
            case STATUS_LINE_PROTOCOL:
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
                    self.response.parse_status_code(self.status_code_cache.str_view())!;

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
                break;

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

// TODO:
// 1. Turn each state into
fn ParserState? Parser.step_old(&self, char[] input)
{
    if (input.len == 0) return EOF;

    self.buf.write(input)!!;

    usz idx = self.buf.read_idx;
    while (idx < self.buf.write_idx)
    {
        switch(self.state)
        {
            case STATUS_LINE:
                ParserState result = self.step_status_line(idx)!;

                if (result == REQUEST_MORE) return result;
                if (result == HEADER)
                {
                    idx += CRLF_OFFSET;
                    self.buf.read_idx = idx;
                    break;
                }

                idx++;

            case HEADER:
                ParserState result = self.step_headers(idx)!;

                if (result == HEADER_READ)
                {
                    idx += CRLF_OFFSET;
                    self.buf.read_idx = idx;

                    continue;
                }
                if (result == HEADER_PROGRESS) idx++;
                if (result == REQUEST_MORE) return result;
                if (result == BODY)
                {
                    idx += CRLF_OFFSET;
                    self.buf.read_idx = idx;

                    self.response.parse_body_type();
                    break;
                }

            case BODY:
                BodyParserState body_result = self.step_body(&self.buf.read_idx, &self.buf.write_idx, self.response.body)!;
                if (body_result == EOF) return REQUEST_MORE;
                if (body_result == BodyParserState.COMPLETE) return COMPLETE;

            default:
                return self.state;
        }
    }

    if (self.state != COMPLETE) return REQUEST_MORE;

    return self.state;
}


fn ParserState? Parser.step_status_line(&self, usz idx)
{
    // Check for a malformed CLRF. This is for a lone LF.
    if (self.buf.bytes[idx] == '\n')
    {
        if (idx == 0 || self.buf.bytes[idx - 1] != '\r')
        {
            return MALFORMED_CRLF?;
        }
    }

    // We've reached EOF without finding the full CRLF - request more bytes.
    if (idx >= (self.buf.write_idx - 1)) return REQUEST_MORE;

    // We've identified the CR, parse the next byte for LF, we've already
    // done the check above for EOF.
    if (self.buf.bytes[idx] == '\r')
    {
        if (idx + 1 < self.buf.write_idx && self.buf.bytes[idx + 1] != '\n')
        {
            return MALFORMED_CRLF?;
        }

        String line = (String) self.buf.bytes[self.buf.read_idx..idx];
        self.response.parse_status_line(line)!;
        self.state = HEADER;
    }

    return self.state;

}
fn ParserState? Parser.step_headers(&self, usz idx)
{
    if (
        self.buf.bytes[idx] == '\r' &&
        self.buf.bytes[idx + 1] == '\n' &&
        self.buf.bytes[idx - 2] == '\r' &&
        self.buf.bytes[idx - 1] == '\n'
    )
    {
        self.state = BODY;
        return self.state;
    }

    if (idx >= (self.buf.write_idx - 1))
    {
        // We have a malformed CRLF, we have the LF without a previous CR which
        // would indicate a double crlf.
        if (self.buf.bytes[idx] == '\n' && self.buf.bytes[idx - 1] != '\r')
        {
            return MALFORMED_CRLF?;
        }

        return REQUEST_MORE;
    }

    if (self.buf.bytes[idx] == '\r')
    {
        if (self.buf.bytes[idx + 1] != '\n') return MALFORMED_CRLF?;

        // We found the clrf, read the single header.
        String line = (String) self.buf.bytes[self.buf.read_idx..idx];
        self.response.parse_header_line(line)!;

        if (idx >= (self.buf.write_idx - 1)) return REQUEST_MORE;

        return HEADER_READ;
    }

    return HEADER_PROGRESS;
}

struct BodyParserResult
{
    BodyParserState state;
    usz bytes_read;
}

// TODO: MAYBE should be step_body?, there should be some rule to identify chunk or not
fn BodyParserState? Parser.step_body(&self, usz* idx, usz* end, DString body)
{
    while (*idx < *end)
    {
    switch(self.body_parser.state)
    {
        case READ_HEX_NUM:
            if (self.buf.bytes[*idx] != '\r')
            {
                io::printfn("Adding to chunk size hex");
                self.body_parser.chunk_size_cache.append_char(self.buf.bytes[*idx]);
                (*idx)++;
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
            (*idx)++;
            break;

        case AFTER_HEX_LF:
            if (self.buf.bytes[*idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = READ_CHUNK;
            (*idx)++;
            break;

        case READ_CHUNK:
            if (self.body_parser.chunk_size_read > 0)
            {
                body.append_char(self.buf.bytes[*idx]);
                self.body_parser.chunk_size_read--;
                (*idx)++;
            }
            else
            {
                self.body_parser.state = AFTER_CHUNK_CR;
            }

            break;

        case AFTER_CHUNK_CR:
            if (self.buf.bytes[*idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = AFTER_CHUNK_LF;
            (*idx)++;
            break;

        case AFTER_CHUNK_LF:
            if (self.buf.bytes[*idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = READ_HEX_NUM;
            (*idx)++;
            break;

        case ZERO_HEX_CR:
            if (self.buf.bytes[*idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = ZERO_HEX_LF;
            (*idx)++;
            break;

        case ZERO_HEX_LF:
            if (self.buf.bytes[*idx] != '\n') return MALFORMED_CRLF?;
            self.body_parser.state = EXTENSION;
            (*idx)++;
            break;

        case EXTENSION:
            if (self.buf.bytes[*idx] == '\r') self.body_parser.state = DOUBLE_CR;
            break;

        case DOUBLE_CR:
            if (self.buf.bytes[*idx] != '\r') return MALFORMED_CRLF?;
            self.body_parser.state = DOUBLE_LF;
            (*idx)++;
            break;

        case DOUBLE_LF:
            if (self.buf.bytes[*idx] == '\n') self.body_parser.state = COMPLETE;
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

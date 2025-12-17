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
}

struct Parser
{
    Allocator allocator;
    ParserState state;
    io::ByteBuffer buf;
    Response response;
    BodyParser body_parser;
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
    DString chunk_size_hex;
}

fn void BodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = READ_HEX_NUM;
    self.chunk_size_hex.init(self.allocator);
}

fn void BodyParser.free(&self)
{
    self.chunk_size_hex.free();
}

fn void Parser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.response.init(self.allocator);
    self.body_parser.init(self.allocator);
}

fn void Parser.tinit(&self) => self.init(tmem);

fn void Parser.free(&self)
{
   self.buf.free();
   self.response.free();
   self.body_parser.free();
}

fn ParserState? Parser.step(&self, char[] input)
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
    io::printfn("beginning idx: %d", *idx);
    io::printfn("end idx: %d", (*end));

    while (*idx < *end)
    {
    switch(self.body_parser.state)
    {
        case READ_HEX_NUM:
            if (self.buf.bytes[*idx] != '\r')
            {
                io::printfn("Adding to chunk size hex");
                self.body_parser.chunk_size_hex.append_char(self.buf.bytes[*idx]);
                (*idx)++;
            }
            else
            {
                ulong chunk_size = self.body_parser.chunk_size_hex.str_view().to_uint(base: 16)!;
                self.body_parser.chunk_size_read = chunk_size;
                self.body_parser.chunk_size_hex.clear();

                self.body_parser.state = AFTER_HEX_CR;

                if (self.body_parser.chunk_size_read == 0)
                {
                    self.body_parser.state = ZERO_HEX_CR;
                }
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
                io::printfn("in read chunk, pushing char: %c", self.buf.bytes[*idx]);
                self.body_parser.chunk_size_read--;
                io::printfn("in read chunk: body: %s", body.str_view());
                (*idx)++;
            }
            else
            {
                self.body_parser.state = AFTER_CHUNK_CR;
            }

            break;

        case AFTER_CHUNK_CR:
            if (self.buf.bytes[*idx] != '\r') return MALFORMED_CRLF?;
            (*idx)++;
            self.body_parser.state = AFTER_CHUNK_LF;
            break;

        case AFTER_CHUNK_LF:
            if (self.buf.bytes[*idx] != '\n') return MALFORMED_CRLF?;
            (*idx)++;
            self.body_parser.state = READ_HEX_NUM;
            break;

        case ZERO_HEX_CR:
            if (self.buf.bytes[*idx] != '\r') return MALFORMED_CRLF?;

            if (self.buf.bytes[*idx] == '\r')
            {
                io::printfn("current byte in zero hex cr IS 'cr'");
            }

            (*idx)++;
            self.body_parser.state = ZERO_HEX_LF;
            break;

        case ZERO_HEX_LF:
            if (self.buf.bytes[*idx] != '\n') return MALFORMED_CRLF?;
            (*idx)++;
            self.body_parser.state = EXTENSION;
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

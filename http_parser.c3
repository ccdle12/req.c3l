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
}

struct Parser
{
    Allocator allocator;
    ParserState state;
    io::ByteBuffer buf;
    Response response;
}

fn void Parser.tinit(&self)
{
    self.allocator = tmem;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.response.init(self.allocator);
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
                ParserState status_line_step = self.step_status_line(&idx)!;

                if (status_line_step == REQUEST_MORE) return status_line_step;
                if (status_line_step == HEADER) break;

                idx++;

            case HEADER:
                ParserState header_step = self.step_headers(&idx)!;

                if (header_step == HEADER_READ) continue;
                if (header_step == HEADER_PROGRESS) idx++;
                if (header_step == REQUEST_MORE) return header_step;
                if (header_step == BODY)
                {
                    self.response.parse_body_type();
                    break;
                }

            case BODY:
                //self.state = COMPLETE;
                return self.state;

            default:
                return self.state;
        }
    }

    if (self.state != COMPLETE) return REQUEST_MORE;

    return self.state;
}

fn ParserState? Parser.step_status_line(&self, usz* idx)
{
    // Check for a malformed CLRF. This is for a lone LF.
    if (self.buf.bytes[*idx] == '\n')
    {
        if (*idx == 0 || self.buf.bytes[*idx - 1] != '\r')
        {
            return MALFORMED_CRLF?;
        }
    }

    // We've reached EOF without finding the full CRLF - request more bytes.
    if (*idx >= (self.buf.write_idx - 1)) return REQUEST_MORE;

    // We've identified the CR, parse the next byte for LF, we've already
    // done the check above for EOF.
    if (self.buf.bytes[*idx] == '\r')
    {
        if (*idx + 1 < self.buf.write_idx && self.buf.bytes[*idx + 1] != '\n')
        {
            return MALFORMED_CRLF?;
        }

        String line = (String) self.buf.bytes[self.buf.read_idx..*idx];
        self.response.parse_status_line(line)!;
        self.state = HEADER;

        *idx += CRLF_OFFSET;
        self.buf.read_idx = *idx;
    }

    return self.state;

}
fn ParserState? Parser.step_headers(&self, usz* idx)
{
    if (
        self.buf.bytes[*idx] == '\r' &&
        self.buf.bytes[*idx + 1] == '\n' &&
        self.buf.bytes[*idx - 2] == '\r' &&
        self.buf.bytes[*idx - 1] == '\n'
    )
    {
        self.state = BODY;
        return self.state;
    }

    if (*idx >= (self.buf.write_idx - 1))
    {
        // We have a malformed CRLF, we have the LF without a previous CR which
        // would indicate a double crlf.
        if (self.buf.bytes[*idx] == '\n' && self.buf.bytes[*idx - 1] != '\r')
        {
            return MALFORMED_CRLF?;
        }

        return REQUEST_MORE;
    }

    if (self.buf.bytes[*idx] == '\r')
    {
        if (self.buf.bytes[*idx + 1] != '\n') return MALFORMED_CRLF?;

        // We found the clrf, read the single header.
        String line = (String) self.buf.bytes[self.buf.read_idx..*idx];
        self.response.parse_header_line(line)!;

        *idx += CRLF_OFFSET;
        self.buf.read_idx = *idx;

        if (*idx >= (self.buf.write_idx - 1)) return REQUEST_MORE;
        return HEADER_READ;
    }

    return HEADER_PROGRESS;
}

fn String Parser.buf_str_view(&self) => (String) self.buf.bytes;

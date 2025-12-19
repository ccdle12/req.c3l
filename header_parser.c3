module req;

import std::io;

enum HeaderState
{
    HEADER_KEY,
    HEADER_VALUE,
    AFTER_HEADER_CR,
    AFTER_HEADER_LF,
    DOUBLE_CR,
    DOUBLE_LF,
    COMPLETE,
    EOF,
}

struct HeaderParser
{
    Allocator allocator;
    HeaderState state;

    DString tmp_header;
    DString tmp_header_val;
}

fn void HeaderParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEADER_KEY;

    self.tmp_header.init(self.allocator);
    self.tmp_header_val.init(self.allocator);
}

fn void HeaderParser.free(&self)
{
   self.tmp_header.free();
   self.tmp_header_val.free();
}

// TODO: Maybe make these StatusLineStates?
fn HeaderState? HeaderParser.step(&self, usz* read_idx, usz* write_idx, char[] buf, Response* response)
{
    while (*read_idx < *write_idx)
    {
        switch(self.state)
        {
        case HEADER_KEY:
            if (buf[*read_idx] == '\r')
            {
                self.state = DOUBLE_CR;
                break;
            }

            // TODO: Need to return error if whitespace before ':'
            if (buf[*read_idx] == ':')
            {
                self.state = HEADER_VALUE;
                (*read_idx)++;
                break;
            }

            self.tmp_header.append_char(buf[*read_idx]);
            (*read_idx)++;
            break;

        case HEADER_VALUE:
            // Catching if we hav a LF out of place, passes to the CR handler
            // to return the error.
            if (buf[*read_idx] == '\n')
            {
                self.state = AFTER_HEADER_CR;
                break;
            }

            if (buf[*read_idx] != '\r')
            {
                self.tmp_header_val.append_char(buf[*read_idx]);
                (*read_idx)++;
                break;
            }

            // TODO: Need to check if this memory frees correctly?
            response.parse_and_set_kv(self.tmp_header, self.tmp_header_val)!;

            self.tmp_header.clear();
            self.tmp_header_val.clear();

            // Set body type as it the headers arrive, we will enforce RFC 9112
            // 6.1 - Transfer Encoding has precendence over Content-Length.
            response.set_body_type();

            self.state = AFTER_HEADER_CR;

            break;

        case AFTER_HEADER_CR:
            if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = AFTER_HEADER_LF;
            break;

        case AFTER_HEADER_LF:
            if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = HEADER_KEY;
            break;

        case DOUBLE_CR:
            if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
            (*read_idx)++;
            self.state = COMPLETE;
            return self.state;

        default:
            break;
        }
    }

    io::printfn("returning request more?");
    return EOF;
}

module req;

import std::io;

enum HeaderState
{
    HEADER_KEY,
    HEADER_VALUE,
    HEADER_CR,
    HEADER_LF,
    DOUBLE_CR,
    DOUBLE_LF,
    EOF,
    COMPLETE,
}

struct HeaderParser
{
    Allocator allocator;
    HeaderState state;

    DString tmp_header_key;
    DString tmp_header_val;
}

fn void HeaderParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEADER_KEY;

    self.tmp_header_key.init(self.allocator);
    self.tmp_header_val.init(self.allocator);
}

fn void HeaderParser.free(&self)
{
   self.tmp_header_key.free();
   self.tmp_header_val.free();
}

fn HeaderState? HeaderParser.step(&self, io::ByteBuffer* byte_buf, Response* response)
{
    usz *read_idx = &byte_buf.read_idx;
    usz write_idx = byte_buf.write_idx;
    char[] buf = byte_buf.bytes;

    while (*read_idx < write_idx)
    {
        switch(self.state)
        {
            case HEADER_KEY:
                if (buf[*read_idx] == '\r')
                {
                    self.state = DOUBLE_CR;
                    break;
                }

                if (buf[*read_idx] == ':')
                {
                    self.state = HEADER_VALUE;
                    (*read_idx)++;
                    break;
                }

                self.tmp_header_key.append_char(buf[*read_idx]);
                (*read_idx)++;
                break;

            case HEADER_VALUE:
                // If we have a LF out of place, we jump to the CR handler
                // to return the error.
                if (buf[*read_idx] == '\n')
                {
                    self.state = HEADER_CR;
                    break;
                }

                if (buf[*read_idx] != '\r')
                {
                    self.tmp_header_val.append_char(buf[*read_idx]);
                    (*read_idx)++;
                    break;
                }

                response.parse_and_set_kv(self.tmp_header_key, self.tmp_header_val)!;

                self.tmp_header_key.clear();
                self.tmp_header_val.clear();

                // Set body type as the headers arrive. We enforce RFC 9112 6.1 -
                // Transfer Encoding has precendence over Content-Length.
                response.set_body_type();

                self.state = HEADER_CR;

                break;

            case HEADER_CR:
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = HEADER_LF;
                break;

            case HEADER_LF:
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = HEADER_KEY;
                break;

            case DOUBLE_CR:
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = DOUBLE_LF;
                break;

            case DOUBLE_LF:
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = COMPLETE;
                return self.state;

            default:
                break;
        }
    }

    return EOF;
}

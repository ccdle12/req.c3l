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

fn ParserResult? HeaderParser.step(&self, char current, Response* response)
{
    switch(self.state)
    {
        case HEADER_KEY:
            if (current == '\r')
            {
                self.state = DOUBLE_LF;
                break;
            }

            if (current == ':')
            {
                self.state = HEADER_VALUE;
                break;
            }

            self.tmp_header_key.append_char(current);
            break;

        case HEADER_VALUE:
            // Handle incorrect ordering of crlf.
            if (current == '\n') return MALFORMED_CRLF?;

            if (current != '\r')
            {
                self.tmp_header_val.append_char(current);
                break;
            }

            response.parse_and_set_kv(self.tmp_header_key, self.tmp_header_val)!;

            self.tmp_header_key.clear();
            self.tmp_header_val.clear();

            // Set body type as the headers arrive. We enforce RFC 9112 6.1 -
            // Transfer Encoding has precendence over Content-Length.
            response.set_body_type();

            // TODO: Skipping over to LF since we confirmed CR here
            self.state = HEADER_LF;

            break;

        case HEADER_CR:
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = HEADER_LF;
            break;

        case HEADER_LF:
            if (current != '\n') return MALFORMED_CRLF?;
            self.state = HEADER_KEY;
            break;

        case DOUBLE_CR:
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            if (current != '\n') return MALFORMED_CRLF?;
            self.state = COMPLETE;
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

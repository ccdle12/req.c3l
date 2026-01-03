module req::http1;

import std::io;

enum HeaderState
{
    HEADER_KEY,
    HEADER_VALUE,
    HEADER_LF,
    DOUBLE_CR,
    DOUBLE_LF,
    COMPLETE,
}

struct HeaderParser (ParserStep)
{
    Allocator allocator;
    HeaderState state;

    DString header_key_cache;
    DString header_val_cache;
}

fn void HeaderParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEADER_KEY;

    self.header_key_cache.init(self.allocator);
    self.header_val_cache.init(self.allocator);
}

fn void HeaderParser.free(&self)
{
   self.header_key_cache.free();
   self.header_val_cache.free();
}

fn ParserResult? HeaderParser.step(&self, char current, Response* response) @dynamic
{
    switch(self.state)
    {
        case HEADER_KEY:
            if (current == CR)
            {
                self.state = DOUBLE_LF;
                break;
            }

            if (current == ':')
            {
                self.state = HEADER_VALUE;
                break;
            }

            self.header_key_cache.append_char(current);
            break;

        case HEADER_VALUE:
            // Handle incorrect ordering of CRLF.
            if (current == LF) return MALFORMED_CRLF?;
            if (current == CR)
            {
                response.parse_and_set_kv(self.header_key_cache, self.header_val_cache)!;

                self.header_key_cache.clear();
                self.header_val_cache.clear();

                // Set body type as the headers arrive. We enforce RFC 9112 6.1 -
                // Transfer Encoding has precendence over Content-Length.
                response.set_body_type();

                self.state = HEADER_LF;
                break;
            }

            self.header_val_cache.append_char(current);
            break;

        case HEADER_LF:
            assert_lf(current)!;
            self.state = HEADER_KEY;
            break;

        case DOUBLE_CR:
            assert_cr(current)!;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            assert_lf(current)!;
            self.state = COMPLETE;
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

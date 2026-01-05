module req::http1;

import std::io;

enum HeaderState
{
    HEADER_KEY,
    HEADER_VALUE,
    HEADER_LF,
    DOUBLE_LF,
    COMPLETE,
}

struct HeaderParser (HttpStepParser)
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

fn HttpParserResult? HeaderParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    switch(self.state)
    {
        case HEADER_KEY:
            if (byte == CR)
            {
                self.state = DOUBLE_LF;
                break;
            }

            if (byte == ':')
            {
                self.state = HEADER_VALUE;
                break;
            }

            self.header_key_cache.append_char(byte);
            break;

        case HEADER_VALUE:
            // Handle incorrect ordering of CRLF.
            if (byte == LF) return MALFORMED_CRLF?;
            if (byte == CR)
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

            self.header_val_cache.append_char(byte);
            break;

        case HEADER_LF:
            assert_lf(byte)!;
            self.state = HEADER_KEY;
            break;

        case DOUBLE_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

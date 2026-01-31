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

struct HeaderParser
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

macro HttpParserResult? HeaderParser.@step(&self, char byte, http_request_or_response)
{
    $assert($defined(http_request_or_response.parse_and_set_header));

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

        case HEADER_VALUE:
            // Handle incorrect ordering of CRLF.
            if (byte == LF) return MALFORMED_CRLF?;
            if (byte == CR)
            {
                String key = self.header_key_cache.str_view();
                defer self.header_key_cache.clear();

                String value = self.header_val_cache.str_view();
                defer self.header_val_cache.clear();

                http_request_or_response.parse_and_set_header(key, value)!;

                self.state = HEADER_LF;
                break;
            }

            self.header_val_cache.append_char(byte);

        case HEADER_LF:
            assert_lf(byte)!;
            self.state = HEADER_KEY;

        case DOUBLE_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

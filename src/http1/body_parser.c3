module req::http1;

import std::io;

enum BodyParserState
{
    HEX_NUM,
    HEX_CR,
    HEX_LF,
    READ_CHUNK,
    CHUNK_CR,
    CHUNK_LF,
    ZERO_HEX_CR,
    ZERO_HEX_LF,
    EXTENSION,
    DOUBLE_CR,
    DOUBLE_LF,
    COMPLETE,
}

struct BodyParser
{
    Allocator allocator;
    BodyParserState state;
    ulong chunk_size;
    DString chunk_size_cache;
}

fn void BodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEX_NUM;
    self.chunk_size_cache.init(self.allocator);
}

fn void BodyParser.free(&self) => self.chunk_size_cache.free();

// TODO: MAYBE should be step_body?, there should be some rule to identify chunk or not
fn ParserResult? BodyParser.step(&self, char current, Response* response)
{
    switch(self.state)
    {
        case HEX_NUM:
            if (current == CR)
            {
                self.chunk_size = self.chunk_size_cache.str_view().to_uint(base: 16)!;
                self.chunk_size_cache.clear();

                if (self.chunk_size == 0)
                {
                    self.state = ZERO_HEX_CR;
                    break;
                }

                self.state = HEX_CR;

                break;
            }

            self.chunk_size_cache.append_char(current);
            break;

        case HEX_CR:
            if (current != CR) return MALFORMED_CRLF?;
            self.state = HEX_LF;
            break;

        case HEX_LF:
            if (current != LF) return MALFORMED_CRLF?;
            self.state = READ_CHUNK;
            break;

        case READ_CHUNK:
            if (self.chunk_size > 0)
            {
                response.body.append_char(current);
                self.chunk_size--;
                break;
            }

            self.state = CHUNK_CR;
            break;

        case CHUNK_CR:
            assert_cr(current)!;
            self.state = CHUNK_LF;
            break;

        case CHUNK_LF:
            assert_lf(current)!;
            self.state = HEX_NUM;
            break;

        case ZERO_HEX_CR:
            assert_cr(current)!;
            self.state = ZERO_HEX_LF;
            break;

        case ZERO_HEX_LF:
            assert_lf(current)!;
            self.state = EXTENSION;
            break;

        case EXTENSION:
            assert_cr(current)!;
            break;

        case DOUBLE_CR:
            assert_cr(current)!;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            if (current == LF) self.state = COMPLETE;
            break;

        default:
            break;
    }

    return REQUEST_MORE;
}

module req::http1;

import std::io;

enum BodyParserState
{
    HEX_NUM,
    HEX_LF,
    READ_CHUNK,
    CHUNK_LF,
    ZERO_HEX_LF,
    EXTENSION,
    DOUBLE_LF,
    COMPLETE,
}

struct BodyParser (HttpStepParser)
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
fn HttpParserResult? BodyParser.step(&self, char current, Response* response) @dynamic
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
                    self.state = ZERO_HEX_LF;
                    break;
                }

                self.state = HEX_LF;

                break;
            }

            self.chunk_size_cache.append_char(current);
            break;

        case HEX_LF:
            assert_lf(current)!;
            self.state = READ_CHUNK;
            break;

        case READ_CHUNK:
            if (self.chunk_size > 0)
            {
                response.body.append_char(current);
                self.chunk_size--;
                break;
            }

            self.state = CHUNK_LF;
            break;

        case CHUNK_LF:
            assert_lf(current)!;
            self.state = HEX_NUM;
            break;

        case ZERO_HEX_LF:
            assert_lf(current)!;
            self.state = EXTENSION;
            break;

        case EXTENSION:
            if (current == CR) self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            assert_lf(current)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE:
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

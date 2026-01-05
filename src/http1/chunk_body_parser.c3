module req::http1;

enum ChunkBodyParserState
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

struct ChunkBodyParser (HttpStepParser)
{
    Allocator allocator;
    ulong chunk_size;
    ChunkBodyParserState state;
    DString chunk_size_cache;
}

fn void ChunkBodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEX_NUM;
    self.chunk_size_cache.init(self.allocator);
}

fn void ChunkBodyParser.free(&self) => self.chunk_size_cache.free();

fn HttpParserResult? ChunkBodyParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    switch(self.state)
    {
        case HEX_NUM:
            if (byte == CR)
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

            self.chunk_size_cache.append_char(byte);
            break;

        case HEX_LF:
            assert_lf(byte)!;
            self.state = READ_CHUNK;
            break;

        case READ_CHUNK:
            if (self.chunk_size > 0)
            {
                response.body.append_char(byte);
                self.chunk_size--;
                break;
            }

            self.state = CHUNK_LF;
            break;

        case CHUNK_LF:
            assert_lf(byte)!;
            self.state = HEX_NUM;
            break;

        case ZERO_HEX_LF:
            assert_lf(byte)!;
            self.state = EXTENSION;
            break;

        case EXTENSION:
            if (byte == CR) self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE:
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

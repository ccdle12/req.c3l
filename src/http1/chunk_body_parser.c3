module req::http1;

enum ChunkBodyParserState
{
    HEX_NUM,
    HEX_LF,
    READ_CHUNK,
    CHUNK_LF,
    ZERO_HEX_LF,
    EXTENSION,
    DOUBLE_CR,
    DOUBLE_LF,
    COMPLETE,
}

struct ChunkBodyParser (HttpStepParser)
{
    Allocator allocator;
    ulong chunk_size;
    ChunkBodyParserState state;
    DString chunk_size_cache;
    DString extensions_cache;
}

fn void ChunkBodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HEX_NUM;
    self.chunk_size_cache.init(self.allocator);
    self.extensions_cache.init(self.allocator);
}

fn void ChunkBodyParser.free(&self)
{
    self.chunk_size_cache.free();
    self.extensions_cache.free();
}

fn HttpParserResult? ChunkBodyParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    switch(self.state)
    {
        case HEX_NUM:
            if (byte == CR || byte == ';')
            {
                self.chunk_size = self.chunk_size_cache.str_view().to_uint(base: 16)!;
                defer self.chunk_size_cache.clear();

                if (self.chunk_size == 0)
                {
                    self.state = ZERO_HEX_LF;
                    break;
                }

                if (byte == ';')
                {
                    self.state = EXTENSION;
                    break;
                }

                self.state = HEX_LF;
                break;
            }

            self.chunk_size_cache.append_char(byte);

        case HEX_LF:
            assert_lf(byte)!;
            self.state = READ_CHUNK;

        case READ_CHUNK:
            if (self.chunk_size > 0)
            {
                response.append_to_body(byte);
                self.chunk_size--;
                break;
            }

            self.state = CHUNK_LF;

        case CHUNK_LF:
            assert_lf(byte)!;
            self.state = HEX_NUM;

        case ZERO_HEX_LF:
            assert_lf(byte)!;
            self.state = DOUBLE_CR;

        case EXTENSION:
            if (byte == CR)
            {
                response.parse_and_set_extensions(self.extensions_cache.str_view());
                defer self.extensions_cache.clear();

                self.state = HEX_LF;
                break;
            }

            self.extensions_cache.append_char(byte);

        case DOUBLE_CR:
            assert_cr(byte)!;
            self.state = DOUBLE_LF;

        case DOUBLE_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

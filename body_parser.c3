module req;

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
    ulong chunk_size_read;
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
fn ParserResult? BodyParser.step(&self, io::ByteBuffer* byte_buf, Response* response)
{
    usz *read_idx = &byte_buf.read_idx;
    usz write_idx = byte_buf.write_idx;
    char[] buf = byte_buf.bytes;

        switch(self.state)
        {
            case HEX_NUM:
                if (buf[*read_idx] != '\r')
                {
                    self.chunk_size_cache.append_char(buf[*read_idx]);
                    (*read_idx)++;
                    break;
                }

                ulong chunk_size = self.chunk_size_cache.str_view().to_uint(base: 16)!;
                self.chunk_size_read = chunk_size;
                self.chunk_size_cache.clear();

                io::printfn("before: chunk size read: %d", self.chunk_size_read);
                if (self.chunk_size_read == 0)
                {
                    io::printfn("setting zero hex cr");
                    self.state = ZERO_HEX_CR;
                }
                else
                {
                    self.state = HEX_CR;
                }

                break;

            case HEX_CR:
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = HEX_LF;
                break;

            case HEX_LF:
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = READ_CHUNK;
                break;

            case READ_CHUNK:
                if (self.chunk_size_read > 0)
                {
                    response.body.append_char(buf[*read_idx]);
                    self.chunk_size_read--;
                    (*read_idx)++;
                }
                else
                {
                    self.state = CHUNK_CR;
                }

                break;

            case CHUNK_CR:
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = CHUNK_LF;
                break;

            case CHUNK_LF:
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = HEX_NUM;
                break;

            case ZERO_HEX_CR:
                io::printfn("in zero hex cr");
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = ZERO_HEX_LF;
                break;

            case ZERO_HEX_LF:
                io::printfn("in zero hex lf");
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = EXTENSION;
                break;

            case EXTENSION:
                if (buf[*read_idx] == '\r') self.state = DOUBLE_CR;
                break;

            case DOUBLE_CR:
                io::printfn("in double cr");
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = DOUBLE_LF;
                break;

            case DOUBLE_LF:
                if (buf[*read_idx] == '\n') self.state = COMPLETE;
                break;

            case COMPLETE:
                (*read_idx)++;
                return COMPLETE;

            default:
                break;
        }

    io::printfn("return request mroe");
    return REQUEST_MORE;
}

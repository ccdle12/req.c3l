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
fn ParserResult? BodyParser.step(&self, io::ByteBuffer* byte_buf, Response* response)
{
    // TODO: Delete *read_idx once I update handle_cr and handle_lf to call read_byte?
    //  TODO: Maybe can even call read_byte() from the http_parser and just pass a copy of the char.
    usz *read_idx = &byte_buf.read_idx;
    char current = byte_buf.read_byte()!;

    switch(self.state)
    {
        case HEX_NUM:
            if (current != '\r')
            {
                self.chunk_size_cache.append_char(current);
                break;
            }

            self.chunk_size = self.chunk_size_cache.str_view().to_uint(base: 16)!;
            self.chunk_size_cache.clear();

            if (self.chunk_size == 0)
            {
                self.state = ZERO_HEX_CR;
            }
            else
            {
                self.state = HEX_CR;
            }

            break;

        case HEX_CR:
            // Update this to just do byte_buf.read_byte()!;
            //handle_cr(current, read_idx)!;
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = HEX_LF;
            break;

        case HEX_LF:
            //handle_lf(current, read_idx)!;
            if (current != '\n') return MALFORMED_CRLF?;
            self.state = READ_CHUNK;
            break;

        case READ_CHUNK:
            if (self.chunk_size > 0)
            {
                response.body.append_char(current);
                self.chunk_size--;
                //current = byte_buf.read_byte()!;
            }
            else
            {
                self.state = CHUNK_CR;
            }

            break;

        case CHUNK_CR:
            //handle_cr(current, read_idx)!;
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = CHUNK_LF;
            break;

        case CHUNK_LF:
            //handle_lf(current, read_idx)!;
            if (current != '\n') return MALFORMED_CRLF?;
            self.state = HEX_NUM;
            break;

        case ZERO_HEX_CR:
            //handle_cr(current, read_idx)!;
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = ZERO_HEX_LF;
            break;

        case ZERO_HEX_LF:
            //handle_lf(current, read_idx)!;
            if (current != '\n') return MALFORMED_CRLF?;
            self.state = EXTENSION;
            break;

        case EXTENSION:
            if (current == '\r') self.state = DOUBLE_CR;
            break;

        case DOUBLE_CR:
            //handle_cr(current, read_idx)!;
            if (current != '\r') return MALFORMED_CRLF?;
            self.state = DOUBLE_LF;
            break;

        case DOUBLE_LF:
            if (current == '\n') self.state = COMPLETE;
            break;

        case COMPLETE:
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

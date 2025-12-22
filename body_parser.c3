module req;

import std::io;

enum BodyParserState
{
    READ_HEX_NUM,
    AFTER_HEX_CR,
    AFTER_HEX_LF,
    AFTER_CHUNK_CR,
    AFTER_CHUNK_LF,
    READ_CHUNK,
    READ_CHUNK_FINISHED,
    ZERO_HEX_CR,
    ZERO_HEX_LF,
    EXTENSION,
    DOUBLE_CR,
    DOUBLE_LF,
    EOF,
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
    self.state = READ_HEX_NUM;
    self.chunk_size_cache.init(self.allocator);
}

fn void BodyParser.free(&self)
{
    self.chunk_size_cache.free();
}

// TODO: MAYBE should be step_body?, there should be some rule to identify chunk or not
fn BodyParserState? BodyParser.step(&self, usz* read_idx, usz* write_idx, char[] buf, DString body)
{
    while (*read_idx < *write_idx)
    {
    switch(self.state)
    {
        case READ_HEX_NUM:
            if (buf[*read_idx] != '\r')
            {
                self.chunk_size_cache.append_char(buf[*read_idx]);
                (*read_idx)++;
                break;
            }

            ulong chunk_size = self.chunk_size_cache.str_view().to_uint(base: 16)!;
            self.chunk_size_read = chunk_size;
            self.chunk_size_cache.clear();

            if (self.chunk_size_read == 0)
            {
                self.state = ZERO_HEX_CR;
            }
            else
            {
                self.state = AFTER_HEX_CR;
            }

            break;

        case AFTER_HEX_CR:
            self.state = AFTER_HEX_LF;
            (*read_idx)++;
            break;

        case AFTER_HEX_LF:
            if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.state = READ_CHUNK;
            (*read_idx)++;
            break;

        case READ_CHUNK:
            if (self.chunk_size_read > 0)
            {
                body.append_char(buf[*read_idx]);
                self.chunk_size_read--;
                (*read_idx)++;
            }
            else
            {
                self.state = AFTER_CHUNK_CR;
            }

            break;

        case AFTER_CHUNK_CR:
            if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.state = AFTER_CHUNK_LF;
            (*read_idx)++;
            break;

        case AFTER_CHUNK_LF:
            if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.state = READ_HEX_NUM;
            (*read_idx)++;
            break;

        case ZERO_HEX_CR:
            if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.state = ZERO_HEX_LF;
            (*read_idx)++;
            break;

        case ZERO_HEX_LF:
            if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
            self.state = EXTENSION;
            (*read_idx)++;
            break;

        case EXTENSION:
            if (buf[*read_idx] == '\r') self.state = DOUBLE_CR;
            break;

        case DOUBLE_CR:
            if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
            self.state = DOUBLE_LF;
            (*read_idx)++;
            break;

        case DOUBLE_LF:
            if (buf[*read_idx] == '\n') self.state = COMPLETE;
            break;

        case COMPLETE:
            (*read_idx)++;
            return self.state;

        default:
            return BodyParserState.EOF;
    }
    }

    return BodyParserState.EOF;
}

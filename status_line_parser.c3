module req;

import std::io;

enum StatusLineState
{
    HTTP_VERSION,
    STATUS_CODE,
    STATUS_LINE_CR,
    STATUS_LINE_CF,
    REASON_SPACE,
    OPTIONAL_REASON,
    COMPLETE,
    EOF,
}

struct StatusLineParser
{
    Allocator allocator;
    StatusLineState state;

    DString status_protocol_cache;
    DString status_code_cache;
    DString status_line_reason;
}

fn void StatusLineParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HTTP_VERSION;
}

fn void StatusLineParser.free(&self)
{

   self.status_protocol_cache.free();
   self.status_code_cache.free();
   self.status_line_reason.free();
}

// TODO: I could create pass *io::ByteBuffer, each parser accesses read_idx and write_idx
fn StatusLineState? StatusLineParser.step(&self, usz* read_idx, usz* write_idx, char[] buf, Response* response)
{
    while (*read_idx < *write_idx)
    {
        switch(self.state)
        {
            case HTTP_VERSION:
                // @step_until(target, innercode to execute)
                if (buf[*read_idx] != ' ')
                {
                    self.status_protocol_cache.append_char(buf[*read_idx]);
                }
                else
                {
                    response.parse_http_protocol(self.status_protocol_cache.str_view())!;
                    self.state = STATUS_CODE;
                }

                (*read_idx)++;
                break;

            case STATUS_CODE:
                if (buf[*read_idx] != '\r' && buf[*read_idx] != ' ')
                {
                    self.status_code_cache.append_char(buf[*read_idx]);
                }
                else
                {
                    if (@catch(response.parse_status_code(self.status_code_cache.str_view())))
                    {
                        return INVALID_STATUS_CODE?;
                    }

                    if (buf[*read_idx] == '\r') self.state = STATUS_LINE_CR;
                    if (buf[*read_idx] == ' ') self.state = REASON_SPACE;
                    break;
                }

                (*read_idx)++;
                break;

            case STATUS_LINE_CR:
                if (buf[*read_idx] != '\r') return MALFORMED_CRLF?;
                self.state = STATUS_LINE_CF;
                (*read_idx)++;
                break;

            case STATUS_LINE_CF:
                if (buf[*read_idx] != '\n') return MALFORMED_CRLF?;
                self.state = COMPLETE;
                (*read_idx)++;
                return self.state;

            case REASON_SPACE:
                if (buf[*read_idx] != ' ') return MALFORMED_STATUS_LINE?;
                self.state = OPTIONAL_REASON;
                (*read_idx)++;
                break;

            case OPTIONAL_REASON:
                if (buf[*read_idx] != '\r' && buf[*read_idx] != ' ')
                {
                    self.status_line_reason.append_char(buf[*read_idx]);
                }
                else
                {
                    // TODO: Need to set a max length of this reason phrase?
                    response.reason_phrase = self.status_line_reason.str_view();
                    self.state = STATUS_LINE_CR;
                    break;
                }

                (*read_idx)++;
                break;

            default:
                break;
        }
    }

    return EOF;
}

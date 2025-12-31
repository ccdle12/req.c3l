module req;

import std::io;

enum StatusLineState
{
    HTTP_VERSION,
    STATUS_CODE,
    STATUS_LINE_CR,
    STATUS_LINE_LF,
    REASON_SPACE,
    OPTIONAL_REASON,
    COMPLETE,
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

fn ParserResult? StatusLineParser.step(&self, io::ByteBuffer* byte_buf, Response* response)
{
    usz *read_idx = &byte_buf.read_idx;
    usz write_idx = byte_buf.write_idx;
    char[] buf = byte_buf.bytes;

        switch(self.state)
        {
            case HTTP_VERSION:
                if (buf[*read_idx] != ' ')
                {
                    self.status_protocol_cache.append_char(buf[*read_idx]);
                }
                else
                {
                    String s = self.status_protocol_cache.str_view();
                    response.parse_http_protocol(s)!;
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
                    String s = self.status_code_cache.str_view();
                    if (@catch(response.parse_status_code(s))) return INVALID_STATUS_CODE?;

                    if (buf[*read_idx] == '\r') self.state = STATUS_LINE_CR;
                    if (buf[*read_idx] == ' ') self.state = REASON_SPACE;
                    break;
                }

                (*read_idx)++;
                break;

            case STATUS_LINE_CR:
                handle_cr(buf[*read_idx], read_idx)!;
                self.state = STATUS_LINE_LF;
                break;

            case STATUS_LINE_LF:
                handle_lf(buf[*read_idx], read_idx)!;
                self.state = COMPLETE;
                return COMPLETE;

            case REASON_SPACE:
                if (buf[*read_idx] != ' ') return MALFORMED_STATUS_LINE?;
                (*read_idx)++;
                self.state = OPTIONAL_REASON;
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

    return REQUEST_MORE;
}

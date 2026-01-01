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

fn ParserResult? StatusLineParser.step(&self, char current, Response* response)
{
        switch(self.state)
        {
            case HTTP_VERSION:
                if (current != ' ')
                {
                    self.status_protocol_cache.append_char(current);
                }
                else
                {
                    String s = self.status_protocol_cache.str_view();
                    response.parse_http_protocol(s)!;
                    self.state = STATUS_CODE;
                }

                break;

            case STATUS_CODE:
                if (current != '\r' && current != ' ')
                {
                    self.status_code_cache.append_char(current);
                }
                else
                {
                    String s = self.status_code_cache.str_view();
                    if (@catch(response.parse_status_code(s))) return INVALID_STATUS_CODE?;

                    // TODO: NEED TO SHIFT EVERYTHING because of the current byte being replaced next.
                    if (current == '\r') self.state = STATUS_LINE_LF;
                    if (current == ' ') self.state = OPTIONAL_REASON;
                    break;
                }

                break;

            case STATUS_LINE_CR:
                self.state = STATUS_LINE_LF;
                break;

            case STATUS_LINE_LF:
                if (current != '\n') return MALFORMED_CRLF?;
                io::printfn("setting state as complete and returning complete");
                self.state = COMPLETE;
                return COMPLETE;

            case REASON_SPACE:
                io::printfn("reason space");
                self.state = OPTIONAL_REASON;
                break;

            case OPTIONAL_REASON:
                if (current != '\r' && current != ' ')
                {
                    self.status_line_reason.append_char(current);
                }
                else
                {
                    // TODO: Need to set a max length of this reason phrase?
                    response.reason_phrase = self.status_line_reason.str_view();
                    io::printfn("before status line cr");
                    self.state = STATUS_LINE_LF;
                    break;
                }

                break;

            default:
                break;
    }

    return REQUEST_MORE;
}

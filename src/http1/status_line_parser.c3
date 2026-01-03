module req::http1;

import std::io;

enum StatusLineState
{
    HTTP_VERSION,
    STATUS_CODE,
    STATUS_LINE_LF,
    OPTIONAL_REASON,
    COMPLETE,
}

struct StatusLineParser (ParserStep)
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

fn ParserResult? StatusLineParser.step(&self, char current, Response* response) @dynamic
{
    switch(self.state)
    {
        case HTTP_VERSION:
            if (current == SP)
            {
                String s = self.status_protocol_cache.str_view();
                defer self.status_protocol_cache.clear();
                response.parse_http_protocol(s)!;

                self.state = STATUS_CODE;
                break;
            }

            self.status_protocol_cache.append_char(current);
            break;

        case STATUS_CODE:
            if (current == CR || current == SP)
            {
                String s = self.status_code_cache.str_view();
                defer self.status_code_cache.clear();
                if (@catch(response.parse_status_code(s))) return INVALID_STATUS_CODE?;

                if (current == CR) self.state = STATUS_LINE_LF;
                if (current == SP) self.state = OPTIONAL_REASON;
                break;
            }

            self.status_code_cache.append_char(current);
            break;

        case STATUS_LINE_LF:
            assert_lf(current)!;
            self.state = COMPLETE;
            return COMPLETE;

        case OPTIONAL_REASON:
            if (current == CR || current == SP)
            {
                response.reason_phrase = self.status_line_reason.str_view();
                self.state = STATUS_LINE_LF;
                break;
            }

            self.status_line_reason.append_char(current);
            break;

        case COMPLETE:
            return COMPLETE;

        default:
            break;
    }

    return REQUEST_MORE;
}

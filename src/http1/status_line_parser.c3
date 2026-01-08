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

struct StatusLineParser (HttpStepParser)
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

fn HttpParserResult? StatusLineParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    switch(self.state)
    {
        case HTTP_VERSION:
            if (byte == SP)
            {
                String s = self.status_protocol_cache.str_view();
                defer self.status_protocol_cache.clear();

                response.parse_http_protocol(s)!;

                self.state = STATUS_CODE;
                break;
            }

            self.status_protocol_cache.append_char(byte);

        case STATUS_CODE:
            if (byte == CR || byte == SP)
            {
                String s = self.status_code_cache.str_view();
                defer self.status_code_cache.clear();
                if (@catch(response.parse_status_code(s))) return INVALID_STATUS_CODE?;

                if (byte == CR) self.state = STATUS_LINE_LF;
                if (byte == SP) self.state = OPTIONAL_REASON;
                break;
            }

            self.status_code_cache.append_char(byte);

        case STATUS_LINE_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case OPTIONAL_REASON:
            if (byte == CR || byte == SP)
            {
                response.set_reason_phrase(self.status_line_reason.str_view());
                self.state = STATUS_LINE_LF;
                break;
            }

            self.status_line_reason.append_char(byte);

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

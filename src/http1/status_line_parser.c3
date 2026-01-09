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

    DString http_protocol_cache;
    DString status_code_cache;
    DString optional_reason_cache;
}

fn void StatusLineParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = HTTP_VERSION;
}

fn void StatusLineParser.free(&self)
{

   self.http_protocol_cache.free();
   self.status_code_cache.free();
   self.optional_reason_cache.free();
}

fn HttpParserResult? StatusLineParser.step(&self, char byte, HttpResponse* http_response) @dynamic
{
    switch(self.state)
    {
        case HTTP_VERSION:
            if (byte == SP)
            {
                String http_protocol = self.http_protocol_cache.str_view();
                defer self.http_protocol_cache.clear();

                http_response.parse_http_protocol(http_protocol)!;

                self.state = STATUS_CODE;
                break;
            }

            self.http_protocol_cache.append_char(byte);

        case STATUS_CODE:
            if (byte == CR || byte == SP)
            {
                String status_code = self.status_code_cache.str_view();
                defer self.status_code_cache.clear();
                if (@catch(http_response.parse_status_code(status_code))) return INVALID_STATUS_CODE?;

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
                http_response.set_reason_phrase(self.optional_reason_cache.str_view());
                defer self.optional_reason_cache.clear();
                self.state = STATUS_LINE_LF;
                break;
            }

            self.optional_reason_cache.append_char(byte);

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

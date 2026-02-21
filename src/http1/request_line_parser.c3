module req::http1;

import std::io;

// Request Line. e.g. GET /index.html HTTP/1.1\r\n
enum RequestLineState
{
    REQUEST_TYPE,
    PATH,
    HTTP_VERSION,
    HTTP_VERSION_LF,
    COMPLETE,
}

struct RequestLineParser
{
    Allocator allocator;
    RequestLineState state;

    DString request_type_cache;
    DString path_cache;
    DString http_version_cache;
}

fn void RequestLineParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.state = REQUEST_TYPE;
}

fn void RequestLineParser.free(&self)
{

   self.request_type_cache.free();
   self.path_cache.free();
   self.http_version_cache.free();
}

fn HttpParserResult? RequestLineParser.step(&self, char byte, HttpRequest* http_request)
{
    switch(self.state)
    {
        case REQUEST_TYPE:
            if (byte == SP)
            {
                String request_type = self.request_type_cache.str_view();
                defer self.request_type_cache.clear();

                http_request.parse_http_request(request_type)!;

                self.state = PATH;
                break;
            }

            self.request_type_cache.append_char(byte);

        case PATH:
            if (byte == SP)
            {
                String path_cache = self.path_cache.str_view();
                defer self.path_cache.clear();

                http_request.parse_path(path_cache);

                self.state = HTTP_VERSION;
                break;
            }

            self.path_cache.append_char(byte);

        case HTTP_VERSION:
            if (byte == CR)
            {
                http_request.parse_http_version(self.http_version_cache.str_view());
                defer self.http_version_cache.clear();

                self.state = HTTP_VERSION_LF;
                break;
            }

            self.http_version_cache.append_char(byte);

        case HTTP_VERSION_LF:
            assert_lf(byte)!;
            self.state = COMPLETE;
            return COMPLETE;

        case COMPLETE: return COMPLETE;
    }

    return REQUEST_MORE;
}

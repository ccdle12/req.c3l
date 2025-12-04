module req;

import tora;
import std::io;
import std::collections::map;

faultdef INVALID_PROTOCOL_VERSION,
         MISSING_STATUS_CODE,
         MISSING_CRLF,
         MALFORMED_HEADER,
         INVALID_HEADER_KEY;

const String HTTP10 = "HTTP/1.0";
const String HTTP11 = "HTTP/1.1";
const String CONTENT_LENGTH = "content-length";
const String TRANSFER_ENCODING = "transfer-encoding";

struct Response
{
    Allocator allocator;

    // Status Line.
    String http_version;
    String status_code;

    // Optional according to RFC 9112.
    String reason_phrase;

    LinkedHashMap{String, String} headers;
    BodyType body_type;
    String body;
}

fn void Response.init(&self, Allocator allocator)
{
    self.headers.init(allocator);
    self.allocator = allocator;
}

fn void Response.tinit(&self)
{
    self.allocator = tmem;
    self.headers.init(self.allocator);
}

<*
  parse_header requires a complete header with a terminating CRLF.
  @param buf: `The String buffer containing the full header`
*>
fn void? Response.parse_header(&self, String buf)
{
    if (!buf.contains(CRLF)) return MISSING_CRLF?;

    String only_headers = buf[..buf.index_of(CRLF)!];
    String[] split_headers = only_headers.split(self.allocator, "\r\n", 0);
    tora::debug("split_headers: %s", split_headers);

    self.parse_status_line(split_headers[0])!;
    self.parse_headers(split_headers[1..])!;
    self.parse_body_type()!;
}

fn void? Response.parse_status_line(&self, String header_status_line)
{
    String[] status_line = header_status_line.split(self.allocator, " ", 3);
    if (status_line.len <= 1) return MISSING_STATUS_CODE?;

    self.http_version = status_line[0];
    if (self.http_version != HTTP11 && self.http_version != HTTP10)
    {
        return INVALID_PROTOCOL_VERSION?;
    }

    self.status_code = status_line[1];

    if (status_line.len > 2)
    {
        self.reason_phrase = status_line[2].trim();
    }
}

fn void? Response.parse_headers(&self, String[] headers)
{
    foreach(&header : headers)
    {
        String[] kv = header.split(self.allocator, ":", 2);
        String key = kv[0].trim().to_lower_copy(self.allocator);

        io::printfn("key: %s", key);
        foreach(c : key)
        {
            if (!is_tchar(c)) return INVALID_HEADER_KEY?;
        }

        self.headers.set(key, kv[1].trim());
    }
}

fn String? Response.get_header(&self, String key)
{
    String k = key.trim().to_lower_copy(self.allocator);
    return self.headers.get(k);
}

<* According to RFC9112 6.1:
   There is a priortiy rule that emphasizes that Transfer-Encoding has precedence
   over Content-Length.
*>
fn void? Response.parse_body_type(&self)
{
    fault content_length_excuse = @catch(self.headers.get(CONTENT_LENGTH));
    if (!content_length_excuse)
    {
        self.body_type = CONTENT_LENGTH;
    }

    fault chunked_excuse = @catch(self.headers.get(TRANSFER_ENCODING));
    if (!chunked_excuse)
    {
        self.body_type = CHUNKED;
    }
}

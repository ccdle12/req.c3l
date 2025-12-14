module req;

import std::collections::map;

faultdef INVALID_PROTOCOL_VERSION,
         MISSING_CRLF,
         MALFORMED_HEADER,
         INVALID_HEADER_KEY_SYMBOL,
         MALFORMED_STATUS_LINE,
         INVALID_STATUS_CODE,
         INVALID_TRAILING_SPACE;

const String HTTP10 = "HTTP/1.0";
const String HTTP11 = "HTTP/1.1";
const String CONTENT_LENGTH = "content-length";
const String TRANSFER_ENCODING = "transfer-encoding";

enum BodyType
{
    NULL,
    CHUNKED,
    CONTENT_LENGTH,
}

struct Response
{
    Allocator allocator;

    // Status Line.
    String http_version;
    int status_code;

    // Optional according to RFC 9112.
    String reason_phrase;

    LinkedHashMap{String, String} headers;

    BodyType body_type;
    DString body;
}

fn void Response.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.headers.init(self.allocator);
    self.body.init(self.allocator);
}

fn void Response.tinit(&self) => self.init(tmem);

fn void Response.free(&self)
{
    self.headers.free();
    self.body.free();
}

fn void? Response.parse_status_line(&self, String header_status_line)
{
    String[] status_line = header_status_line.split(self.allocator, " ", 3);
    defer allocator::free(self.allocator, status_line);

    if (status_line.len <= 1) return MALFORMED_STATUS_LINE?;

    if (status_line[0] != HTTP11 && status_line[0] != HTTP10)
    {
        return INVALID_PROTOCOL_VERSION?;
    }
    self.http_version = status_line[0];

    if (status_line[1].len != 3) return INVALID_STATUS_CODE?;
    foreach (c : status_line[1])
    {
        if (!ascii::@is_digit(c)) return INVALID_STATUS_CODE?;
    }
    self.status_code = status_line[1].to_integer(int, 10)!;

    if (status_line.len > 2)
    {
        self.reason_phrase = status_line[2].trim();
    }
}

fn void? Response.parse_header_line(&self, String header_line)
{
    String[] kv = header_line.split(self.allocator, ":", 2);
    defer allocator::free(self.allocator, kv);

    if (kv.len < 2) return MALFORMED_HEADER?;

    String key = kv[0].to_lower_copy(self.allocator);
    defer allocator::free(self.allocator, key);

    if (key[key.len - 1] == ' ') return INVALID_TRAILING_SPACE?;

    foreach(c : key)
    {
        if (!is_tchar(c)) return INVALID_HEADER_KEY_SYMBOL?;
    }

    self.headers.set(key, kv[1].trim());
}

fn String*? Response.get_header_ref(&self, String key)
{
    String k = key.trim().to_lower_copy(self.allocator);
    defer allocator::free(self.allocator, k);

    return self.headers.get_ref(k)!;
}

<* According to RFC9112 6.1:
   There is a priortiy rule that emphasizes that Transfer-Encoding has precedence
   over Content-Length.
*>
fn void Response.parse_body_type(&self)
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

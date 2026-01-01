module req::http1;

import std::collections::map;

faultdef INVALID_PROTOCOL_VERSION,
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
    String reason_phrase; // Optional according to RFC 9112.

    // Headers
    LinkedHashMap{String, String} headers;

    // Body
    BodyType body_type;
    DString body;
}

fn void Response.tinit(&self) => self.init(tmem);

fn void Response.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.headers.init(self.allocator);
    self.body.init(self.allocator, MAX_SIZE);
}

fn void Response.free(&self)
{
    self.headers.free();
    self.body.free();
}

fn void? Response.parse_status_code(&self, String status_code)
{
    if (status_code.len > 3) return INVALID_STATUS_CODE?;
    self.status_code = status_code.to_integer(int, 10)!;
}

fn void? Response.parse_http_protocol(&self, String protocol)
{
    if (protocol != HTTP11 && protocol != HTTP10)
    {
        return INVALID_PROTOCOL_VERSION?;
    }

    self.http_version = protocol;
}

fn void? Response.parse_header(&self, String key)
{
    if (key[key.len - 1] == SP) return INVALID_TRAILING_SPACE?;

    foreach(c : key)
    {
        if (!is_tchar(c)) return INVALID_HEADER_KEY_SYMBOL?;
    }
}

fn void? Response.parse_and_set_kv(&self, DString header_key, DString header_value)
{
    String key = header_key.copy_str(self.allocator).to_lower_copy(self.allocator);
    self.parse_header(key)!;

    String value = header_value.copy_str(self.allocator).trim();

    self.headers.set(key, value);
}

// TODO: This is naive setting for now, we need to be able to handle:
// - compress
// - deflate
// - gzip
fn void Response.set_body_type(&self)
{
    if (self.headers.has_key(CONTENT_LENGTH))    self.body_type = CONTENT_LENGTH;
    if (self.headers.has_key(TRANSFER_ENCODING)) self.body_type = CHUNKED;
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
    if (try self.headers.get(CONTENT_LENGTH))    self.body_type = CONTENT_LENGTH;
    if (try self.headers.get(TRANSFER_ENCODING)) self.body_type = CHUNKED;
}

module req::http1;

import std::collections::map;

faultdef INVALID_PROTOCOL_VERSION,
         INVALID_HEADER_KEY_SYMBOL,
         INVALID_STATUS_CODE,
         INVALID_TRAILING_SPACE;

const String HTTP10 = "HTTP/1.0";
const String HTTP11 = "HTTP/1.1";
const String CONTENT_LENGTH_KEY = "content-length";
const String TRANSFER_ENCODING_KEY = "transfer-encoding";

const ulong DEFAULT_PAGE_SIZE = 16 * mem::KB;

enum BodyType
{
    NULL,
    CHUNKED,
    CONTENT_LENGTH,
}

struct HttpResponse
{
    Allocator allocator;
    // Arena for owning Strings for Status Line, Headers and Extensions maps.
    DynamicArenaAllocator owned_strings;

    // Status Line.
    String http_version;
    int status_code;
    String reason_phrase; // Optional according to RFC 9112.

    // Headers
    LinkedHashMap{String, String} headers;

    // Body
    HashMap{String, String} extensions;
    BodyType body_type;
    DString body;
}

fn void HttpResponse.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.owned_strings.init(self.allocator, DEFAULT_PAGE_SIZE);
    self.headers.init(self.allocator);
    self.body.init(self.allocator, MAX_SIZE);
    self.extensions.init(self.allocator);
}

fn void HttpResponse.tinit(&self) => self.init(tmem);

fn void HttpResponse.free(&self)
{
    self.headers.free();
    self.body.free();
    self.extensions.free();
    self.owned_strings.free();
}

fn void? HttpResponse.parse_status_code(&self, String status_code)
{
    if (status_code.len > 3) return INVALID_STATUS_CODE?;
    self.status_code = status_code.to_integer(int, 10)!;
}

fn void? HttpResponse.parse_http_protocol(&self, String http_version)
{
    if (http_version != HTTP11 && http_version != HTTP10) return INVALID_PROTOCOL_VERSION?;
    self.http_version = http_version.copy(&self.owned_strings);
}

fn void HttpResponse.set_reason_phrase(&self, String reason) => self.reason_phrase = reason.copy(&self.owned_strings);

fn void? HttpResponse.validate_header_key(&self, String key)
{
    if (key[key.len - 1] == SP) return INVALID_TRAILING_SPACE?;

    foreach(c : key)
    {
        if (!is_tchar(c)) return INVALID_HEADER_KEY_SYMBOL?;
    }
}

fn void HttpResponse.parse_and_set_extensions(&self, String extensions) => @pool()
{
    foreach (ext : extensions.tsplit(";"))
    {
        String[] kv = ext.tsplit("=");

        String key = kv[0].trim().copy(&self.owned_strings);
        String value = (kv.len > 1) ? kv[1].trim().copy(&self.owned_strings) : key;

        self.extensions.set(key, value);
    };
}

fn void? HttpResponse.parse_and_set_header(&self, String header_key, String header_value)
{
    self.validate_header_key(header_key)!;
    String key = header_key.trim().to_lower_copy(&self.owned_strings);

    String value = header_value.trim().copy(&self.owned_strings);
    self.headers.set(key, value);
}

fn void HttpResponse.append_to_body(&self, char byte) => self.body.append_char(byte);

// TODO: This is naive setting for now, we need to be able to handle:
// - compress
// - deflate
// - gzip
<* According to RFC9112 6.1:
   There is a priortiy rule that emphasizes that Transfer-Encoding has precedence
   over Content-Length.
*>
fn void HttpResponse.set_body_type(&self)
{
    if (self.headers.has_key(CONTENT_LENGTH_KEY))     self.body_type = CONTENT_LENGTH;
    if (self.headers.has_key(TRANSFER_ENCODING_KEY))  self.body_type = CHUNKED;
}

fn String*? HttpResponse.get_header_ref(&self, String key) => @pool()
{
    String k = key.trim().to_lower_tcopy();
    return self.headers.get_ref(k);
}

<*
  Returns the value of the content length header if it's available.
*>
fn ulong? HttpResponse.get_content_length(&self)
{
    String* content_length = self.get_header_ref(CONTENT_LENGTH_KEY)!;
    return content_length.to_integer(ulong);
}

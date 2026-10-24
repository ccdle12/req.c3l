module req::http1;

import std::collections::map;
import std::collections::list;

faultdef INVALID_PROTOCOL_VERSION,
         INVALID_STATUS_CODE,
         MALFORMED_DUPLICATE_CONTENT_LENGTH;

const String HTTP10 = "HTTP/1.0";
const String HTTP11 = "HTTP/1.1";

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
    DynamicArenaAllocator arena;

    // Status Line.
    String http_version;
    int status_code;
    String reason_phrase; // Optional according to RFC 9112.

    // Headers
    HttpHeaders headers;

    // Body
    HashMap{String, String} extensions;
    ulong content_length;
    BodyType body_type;
    DString body;
}

fn void HttpResponse.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.arena.init(self.allocator, DEFAULT_PAGE_SIZE);
    self.headers.init(&self.arena);
    self.content_length = 0;
    self.body.init(&self.arena, MAX_SIZE);
    self.extensions.init(&self.arena);
}

fn void HttpResponse.tinit(&self) => self.init(tmem);

fn void HttpResponse.free(&self)
{
    self.headers.free();
    self.arena.free();
}

fn void? HttpResponse.parse_status_code(&self, String status_code)
{
    if (status_code.len > 3) return INVALID_STATUS_CODE?;
    self.status_code = status_code.to_integer(int, 10)!;
}

fn void? HttpResponse.parse_http_protocol(&self, String http_version)
{
    if (http_version != HTTP11 && http_version != HTTP10) return INVALID_PROTOCOL_VERSION?;
    self.http_version = http_version.copy(&self.arena);
}

fn void HttpResponse.set_reason_phrase(&self, String reason) => self.reason_phrase = reason.copy(&self.arena);

fn void HttpResponse.parse_and_set_extensions(&self, String extensions) => @pool()
{
    foreach (ext : extensions.tsplit(";"))
    {
        String[] kv = ext.tsplit("=");

        String key = kv[0].trim().copy(&self.arena);
        String value = (kv.len > 1) ? kv[1].trim().copy(&self.arena) : key;

        self.extensions.set(key, value);
    };
}

<*
 Parse a single header (key and raw value), enforce header-specific rules, and
 either append its value to an existing header entry or copy the parsed header
 into the response arena.
 *>
fn void? HttpResponse.parse_and_set_header(&self, String header_key, String header_value) => @pool()
{
    if (tnormalize_key(header_key) == SET_COOKIE)
    {
        self.headers.set_cookie(header_value)!;
        return;
    }

    Header* header = self.headers.push_and_get_header_ref(header_key, header_value)!;

    // Cache the content length if applicable.
    self.try_cache_content_length(header)!;

    // Set body type as the headers arrive. We enforce RFC 9112 6.1 -
    // Transfer Encoding has precendence over Content-Length.
    self.set_body_type();
}

<*
 Caches the content length in th HttpResponse for quicker access if header is a
 `content-length`.
 *>
fn void? HttpResponse.try_cache_content_length(&self, Header* header) @private
{
    if (header.key == CONTENT_LENGTH_KEY) self.content_length = header.values.get(0).to_integer(ulong)!;
}

fn void HttpResponse.append_to_body(&self, char byte) => self.body.append_char(byte);

// TODO: This is a naive setting for now, we need to be able to handle:
// - compress
// - deflate
// - gzip
<*
   Determine and set the response's body framing type based on received headers,
   applying the precedence rule from RFC 9112 §6.1 - Transfer-Encoding has precedence
   over Content-Length
*>
fn void HttpResponse.set_body_type(&self)
{
    if (self.headers.has_key(CONTENT_LENGTH_KEY))     self.body_type = CONTENT_LENGTH;
    if (self.headers.has_key(TRANSFER_ENCODING_KEY))  self.body_type = CHUNKED;
}

fn List{String}*? HttpResponse.get_header_ref(&self, String key) => &self.headers.get_ref(key)!.values;
fn bool HttpResponse.has_content_length(&self) => self.headers.has_key(CONTENT_LENGTH_KEY);

// TODO: This is more or less the same with HttpRequest to_string().
// TODO: Make this a common function for HttpResponse and/or HttpRequest?
<*
 @param [in] self
 @param [inout] allocator : `the allocator that will own the new String.`
 *>
fn String? HttpResponse.to_string(&self, Allocator allocator) => @pool()
{
    DString result;
    result.init(tmem);

    result.appendf("%s %d %s\r\n", self.http_version, self.status_code, self.reason_phrase);

    // TODO: If there are multiple valus for the key, I think I need to be able to print
    // the Key/Value like so: "Key: value, value, value, value"
    self.headers.@each_header(; String key, Header header)
    {
        result.appendf("%s: ", key);
        foreach (idx, &value : header.values)
        {
            // For multiple values, append them as comma-separated values.
            if (idx != header.values.len() - 1) {
                result.appendf("%s, ", *value);
            } else {
                result.appendf("%s\r\n", *value);
            }
        }
    };

    // TODO: This doesn't handle chunked bodies?
    // The double CRLF to separate the headers from the body.
    result.append("\r\n");
    if (self.body_type != NULL)
    {
        result.append(self.body);
        result.append("\r\n");
    }
    return result.copy_str(allocator);
}

module req::http1;

import std::collections::map;

faultdef MALFORMED_HTTP_REQUEST;

enum RequestType : (String name)
{
    GET  = "GET",
    POST = "POST",
}

fn RequestType? request_type_from_string(String request_type) => @pool()
{
    if (tnormalize_key(RequestType.GET.name) == tnormalize_key(request_type))  return GET;
    if (tnormalize_key(RequestType.POST.name) == tnormalize_key(request_type)) return POST;

    return MALFORMED_HTTP_REQUEST?;
}

struct HttpRequest
{
    Allocator allocator;
    DynamicArenaAllocator arena;

    // Request Line. e.g. GET /index.html HTTP/1.1
    RequestType type;
    String path;
    String http_version;

    // e.g. Host: example.com
    String host;

    // Common headers:
    // User-Agent: Mozilla/5.0
    // Content-Type: application/x-www-form-urlencoded
    // Content-Length: 27
    HttpHeaders headers;

    // ONLY on POST.
    String body;
}

fn void HttpRequest.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    // TODO: 2026.02.04 - Update DEFAULT_PAGE_SIZE, if not allocating body here.
    self.arena.init(self.allocator, DEFAULT_PAGE_SIZE);
    self.headers.init(&self.arena);
}

fn void HttpRequest.tinit(&self) => self.init(tmem);

<*
 @param [in] self
 @param [inout] allocator : `the allocator that will own the new String.`
 *>
fn String? HttpRequest.to_string(&self, Allocator allocator) => @pool()
{
    DString result;
    result.init(tmem);

    result.appendf("%s %s %s\r\n", self.type.name, self.path, self.http_version);
    result.appendf("Host: %s\r\n", self.host);

    // TODO: If there are multiple values, I need to repeat the header?
    self.headers.@each_header(; String key, Header header)
    {
        if (header.values.len() == 1)
        {
            result.appendf("%s: %s\r\n", key, header.values.get(0));
        }
    };

    if (self.type == RequestType.POST) result.append(self.body);

    result.append("\r\n");
    return result.copy_str(allocator);
}

<*
 @param [in] self
*>
fn void HttpRequest.free(&self)
{
	if (!self.allocator) return;
    self.arena.free();
	self.body.free(self.allocator);
}

<*
 @param [out] self
*>
fn void? HttpRequest.parse_http_request(&self, String request_type)
{
    RequestType type = request_type_from_string(request_type)!;
    self.type = type;
}

<*
 @param [out] self
*>
fn void? HttpRequest.parse_host(&self, String host)
{
    self.host = host.copy(&self.arena).trim();
}

<*
 @param [out] self
*>
fn void HttpRequest.parse_path(&self, String path)
{
    self.path = path.copy(&self.arena);
}

<*
 @param [out] self
*>
fn void HttpRequest.parse_http_version(&self, String http_version)
{
    self.http_version = http_version.copy(&self.arena);
}

// TODO: This is repeated in HttpResponse and HttpRequest, should it belong
// to another struct/function?
<*
 Parse a single header (key and raw value), enforce header-specific rules, and
 either append its value to an existing header entry or copy the parsed header
 into the response arena.
 *>
fn void? HttpRequest.parse_and_set_header(&self, String header_key, String header_value) => @pool()
{
    if (tnormalize_key(header_key) == SET_COOKIE)
    {
        self.headers.set_cookie(header_value)!;
        return;
    }

    self.headers.push(header_key, header_value)!;
}

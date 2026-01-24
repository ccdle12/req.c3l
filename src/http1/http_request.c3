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
    self.headers.init(self.allocator);
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
	self.path.free(self.allocator);
	self.host.free(self.allocator);
	self.http_version.free(self.allocator);
    self.headers.free();
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
fn void HttpRequest.parse_path(&self, String path)
{
    self.path = path.copy(self.allocator);
}

<*
 @param [out] self
*>
fn void HttpRequest.parse_http_version(&self, String http_version)
{
    self.http_version = http_version.copy(self.allocator);
}

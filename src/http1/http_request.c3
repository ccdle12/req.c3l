module req::http1;

import std::collections::map;

enum RequestType : (String name)
{
    GET  = "GET",
    POST = "POST",
}

struct HttpRequest
{
    Allocator allocator;

    // Request Line. e.g. GET /index.html HTTP/1.1
    RequestType type;
    String path;

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

    result.appendf("%s %s HTTP/1.1\r\n", self.type.name, self.path);
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
    self.headers.free();
	self.body.free(self.allocator);
}

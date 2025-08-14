module req;

import std::collections;
import tora;

alias KVList = List{Pair{String, String}};

enum Method : int (String str)
{
    GET = "GET",
    POST = "POST",
    PUT = "PUT",
    DELETE = "DELETE",
    HEAD = "HEAD",
    OPTIONS = "OPTIONS"
}

enum Version : int (String str)
{
    HTTP1_1 = "HTTP/1.1"
}

enum ContentType : int (String str)
{
    ANY = "*/*",
    JSON = "application/json",
    HTML = "text/html",
    XML = "application/xml",
    TEXT = "text/plain",
    MULTIPART = "multipart/form-data",
    URLENCODED = "application/x-www-form-urlencoded",
}

enum Language : int (String str)
{
    EN_US = "en-us",
}

enum Connection : int (String str)
{
    KEEP_ALIVE = "keep-alive",
    CLOSE = "close"
}

enum Authorization : int (String str)
{
    BASIC = "Authorization: Basic",
    BEARER = "Authorization: Bearer",
    DIGEST = "Authorization: Digest",
}

enum AcceptEncoding : int (String str)
{
    GZIP = "gzip",
    DEFLATE = "deflate",
    BR = "br",
}

struct Headers
{
    String host;
    String user_agent;
    String accept;
    String accept_language;
    String content_type;

    // TODO: Adding these variables for Response
    String date;
    String server;
    String last_modified;

    String authorization;
    String accept_encoding;
    String connection;
    String cookie;
    String via;
    String vary;
    String transfer_encoding;

    usz content_length;
    KVList extra_headers;
}

struct Request
{
    String uri;
    Method method;
    String version;
    Headers headers;

    // TODO: See if theres a better type to use, maybe bytes?
    String body;
}

fn Request init(String uri, Method method, String body, String version=Version.HTTP1_1.str)
{
    return { .uri = uri, .method = method, .version = version, .body = body };
}

fn String Request.serialize(&self)
{
    DString tmp = dstring::temp();

    tmp.appendf("%s ", self.method.str);
    tmp.appendf("%s ", self.uri);
    tmp.appendf("%s\r\n", self.version);
    tmp.appendf("Host: %s\r\n", self.headers.host);
    tmp.appendf("User-Agent: %s\r\n", self.headers.user_agent);
    tmp.appendf("Accept: %s\r\n", self.headers.accept);

    if (self.headers.accept_encoding.len > 0)
    {
        tmp.appendf("Accept-Encoding: %s\r\n", self.headers.accept_encoding);
    }

    if (self.headers.accept_language.len > 0)
    {
        tmp.appendf("Accept-Language: %s\r\n", self.headers.accept_language);
    }

    if (self.headers.connection.len > 0)
    {
        tmp.appendf("Connection: %s\r\n", self.headers.connection);
    }

    if (self.headers.content_type.len > 0)
    {
        tmp.appendf("Content-Type: %s\r\n", self.headers.content_type);
    }

    if (self.headers.content_length > 0)
    {
        tmp.appendf("Content-Length: %s\r\n", self.headers.content_length);
    }

    if (self.headers.via.len > 0)
    {
        tmp.appendf("Via: %s\r\n", self.headers.via);
    }

    // THIS MUST BE REQUIRED AFTER A HEADER, EVEN WITHOUT A BODY
    tmp.appendf("\r\n\r\n");

    if (self.body.len > 0)
    {
        tmp.appendf("%s", self.body);
    }

    tora::debug("\n%s", tmp.str_view());

    return tmp.str_view();
}

module req;

import std::net::url;
import std::net::tcp;
import tora;

fn Response? get(String input, String accept=ContentType.ANY.str, String lang=Language.EN_US.str, String encoding = AcceptEncoding.GZIP.str, String content_type = ContentType.JSON.str)
{
    Url url = url::tparse(input)!;
    tora::debug("url.host: %s", url.host);
    tora::debug("uri path: %s", url.path);

    if (url.path.len == 0)
    {
        tora::debug("url path is empty");
        url.path = "/";
    }

    Headers headers =
    {
        .host = url.host,
        .user_agent = "curl/8.12.1",
        // TODO: Should ask user for content type
        .accept = accept,
        .accept_language = lang,
        .accept_encoding = encoding,
        .content_type = content_type,
        // TODO: SKip auth for now
        // TODO: Skip cookies for now
        // TODO: Skip extra headers for now
    };
    tora::debug("headers.host: %s", headers.host);

    Request request =
    {
        .uri = url.path,
        .method = Method.GET,
        .version = Version.HTTP1_1.str,
        .headers = headers,
    };

    tora::debug("\n%s", request.serialize());

    TcpSocket soc = tcp::connect(headers.host, scheme_to_port(url.scheme))!;
    usz sent_bytes = soc.write(request.serialize())!;

    if (sent_bytes == 0) return FAIL_SEND?;
    tora::debug("sent_bytes: %s", sent_bytes);

    Response response = recv(soc)!!;

    tora::debug("after call to recv()");

    return response;
}

fn uint scheme_to_port(String scheme) @private
{
    scheme.convert_to_lower();

    if (scheme == "http")
    {
            return 80;
    }

    // TODO: We will assume an https connection
    return 443;
}

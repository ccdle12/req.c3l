module req;

import std::net::url;
import std::net::tcp;
import tora;

fn void? post(String input, String body, String accept=ContentType.JSON.str, String lang=Language.EN_US.str, String encoding = AcceptEncoding.GZIP.str, String content_type = ContentType.JSON.str)
{
    Url url = url::tparse(input)!;

    Headers headers =
    {
        .host = url.host,
        .user_agent = "req/http",
        // TODO: Should ask user for content type
        .accept = accept,
        .accept_language = lang,
        .accept_encoding = encoding,
        .content_type = content_type,
        .content_length = body.len,
        // TODO: SKip auth for now
        // TODO: Skip cookies for now
        // TODO: Skip extra headers for now
    };

    Request request =
    {
        .uri = url.path,
        .method = Method.POST,
        .version = Version.HTTP1_1.str,
        .body = body
    };

    tora::debug("BEFORE TCP CONNECT");
    // TODO: Send
    TcpSocket soc = tcp::connect(headers.host, url.port)!;
    tora::debug("AFTER TCP CONNECT");
    tora::debug("BEFORE SOC SERIALIZE");
    soc.write(request.serialize())!;
    tora::debug("AFTER SOC SERIALIZE");
    DString tmp = dstring::temp();

    tora::debug("BEFORE READ TO BUFFER");
    char[1024] buf;
    soc.read(&buf)!;
    tora::debug("AFTER READ TO BUFFER");

    tora::debug("%s", buf);
}

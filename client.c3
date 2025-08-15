module req;

import std::net::url;
import std::net::tcp;
import std::time;
import tora;

const String USER_AGENT = "";

faultdef FAIL_SEND, FAIL_READ;

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

    // TODO: Read everything from read in one-go, only one syscall? Is this better?
    //char[8192] buf;
    //usz read_bytes = soc.read(&buf)!;
    //if (read_bytes == 0) return FAIL_READ?;

    //tora::debug("READ BYTES: %s", read_bytes);
    //tora::debug("DOES THIS WORK:\n %s", (String) &buf);

    //TODO: Check number of read bytes, if 0, return an error.
    //tora::debug("number of read_bytes: %s", read_bytes);

    Socket s = (Socket) soc;
    //Response response;
    //response.recv(&soc)!!;

    Response response;
    response.recv(&s)!!;

    tora::debug("after call to recv()");

    return response;
}

fn uint scheme_to_port(String scheme)
{
    scheme.convert_to_lower();

    if (scheme == "http")
    {
            return 80;
    }

    // TODO: We will assume an https connection
    return 443;
}

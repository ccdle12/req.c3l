module req;

import std::net::tcp;
import std::net;
import std::io;
import tora;

faultdef TIMEOUT;

enum ParserState
{
    START,
    HEADER_DONE,
    BODY_CHUNKED,
    COMPLETE,
    REQUEST_MORE,
}

enum BodyType
{
    NULL,
    CHUNKED,
    CONTENT_LENGTH,
}

// TODO: Maybe make this a kv.
struct Headers
{
    String host;
}

struct Parser
{
    Allocator allocator;
    ParserState state;
    io::ByteBuffer buf;
    Response response;
}

const usz MAX_SIZE = 4096;
const usz INITIAL_CAPACITY = 4096;
const char[] CRLF = "\r\n\r\n";

faultdef CRLF_NOT_FOUND;

fn void Parser.tinit(&self)
{
    self.allocator = tmem;
    self.buf.init(self.allocator, MAX_SIZE, INITIAL_CAPACITY);
    self.response.init(self.allocator);
}

fn ParserState Parser.step(&self, char[] input)
{
    switch(self.state)
    {
        case START:
            if (catch excuse = self.read_header(input))
            {
                if (excuse == CRLF_NOT_FOUND) return REQUEST_MORE;
            }

            self.state = HEADER_DONE;
            return self.state;

        case HEADER_DONE:
            self.state = BODY_CHUNKED;
            return self.state;

        case BODY_CHUNKED:
            self.state = COMPLETE;
            return self.state;

        default:
            return self.state;
    }
}

// TODO: Maybe after reading until crlf_idx and writing to buf and then pass
// to response to parse the header.
fn void? Parser.read_header(&self, char[] input) @private
{
    if (!self.contains_crlf(input))
    {
        self.buf.write(input)!;
        return CRLF_NOT_FOUND?;
    }

    usz crlf_idx = self.find_end_of_crlf(input)!;
    self.buf.write(input[:crlf_idx])!;

    self.response.parse_header(self.buf_str_view())!;


}

fn bool Parser.contains_crlf(&self, char[] input) @private
{
    String x = (String) input;
    return x.contains(CRLF);
}

fn usz? Parser.find_end_of_crlf(&self, char[] input) @private
{
    String x = (String) input;
    return x.index_of(CRLF)! + 4;
}

fn String Parser.buf_str_view(&self)
{
    usz end_idx = self.buf.write_idx - self.buf.read_idx;
    return (String) self.buf.bytes[0:end_idx];
}

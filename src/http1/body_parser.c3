module req::http1;

import std::io;

struct BodyParser
{
    Allocator allocator;
    ChunkBodyParser chunk_body_parser;
    ContentLengthBodyParser content_length_body_parser;
}

fn void BodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.chunk_body_parser.init(self.allocator);
    self.content_length_body_parser.init();
}

fn HttpParserResult? BodyParser.step(&self, char byte, HttpResponse* http_response)
{
    switch(http_response.body_type)
    {
        case NULL:           break;
        case CHUNKED:        return self.chunk_body_parser.step(byte, http_response)!;
        case CONTENT_LENGTH: return self.content_length_body_parser.step(byte, http_response)!;
    }

    return COMPLETE;
}

fn void BodyParser.free(&self)
{
    self.chunk_body_parser.free();
}

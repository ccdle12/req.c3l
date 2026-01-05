module req::http1;

import std::io;

struct BodyParser (HttpStepParser)
{
    Allocator allocator;
    ChunkBodyParser chunk_body_parser;
}

fn void BodyParser.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.chunk_body_parser.init(self.allocator);
}

fn HttpParserResult? BodyParser.step(&self, char byte, HttpResponse* response) @dynamic
{
    switch(response.body_type)
    {
        case NULL:
            break;
        case CHUNKED:
            return self.chunk_body_parser.step(byte, response)!;
        case CONTENT_LENGTH:
            break;

    }

    return COMPLETE;
}

fn void BodyParser.free(&self)
{
    self.chunk_body_parser.free();
}

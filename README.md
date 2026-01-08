# Req C3

An HTTP Library with basic Client/Server and CLI support, written in C3.

## Features

This library will support:

- HTTP/1.1 parsing, serialization and deserialization of Requests and Response
- HTTP/2 framing
- HTTP/3, WebSockets, and QUIC (planned)
- Single-threaded HttpClient and HttpServer

## Dependencies

- Current c3c version:

```
C3 Compiler Version:       0.7.8 (Pre-release, Dec 03 2025 13:47:36)
Git Hash:                  ccffa03de29a531dbfbad69b977e8f96a6433733
Backends:                  LLVM
LLVM version:              19.1.6
```

## Quick Start

- Run tests

```
c3c test
```

## Docs

- [http1 module feature list](./docs/http1_features.md)

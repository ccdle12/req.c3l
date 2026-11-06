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
C3 Compiler Version:       0.8.6 (Pre-release, Nov 06 2026 20:06:06)
Git Hash:                  8a2ac9601ba900a7639eb8a412fc3a9891304c1f
Backends:                  LLVM; C
LLVM version:              19.1.6
```

## Quick Start

- Run tests

```
c3c test
```

## Docs

- [http1 module feature list](./docs/http1_features.md)

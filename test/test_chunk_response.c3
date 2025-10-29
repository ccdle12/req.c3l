module req;

import tora;
import std::net::tcp;
import std::collections;
import std::net::os;
import std::thread;
import std::time;
import std::io;

fn void test_ok_chunked_0() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "access-control-allow-origin: *\r\n",
      "content-type: application/json \r\n",
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n",
      "via: 1.1 Caddy \r\n",
      "transfer-encoding: chunked",

      // Headers and Body separator
      CRLF,

      "18\r\n",
      "{\"key\": \"value\", \"i\": 1}\r\n",
      "0\r\n",

      CRLF_END,
    };

    // Then i'll need to figure out how to call recv(), that has incomplete
    // mock socket and then add more to the mock socket somehow

    Response res = get_response(&input)!!;

    test::eq(res.status, "200");
    test::eq(res.version, "HTTP/1.1");
    test::eq(res.headers.transfer_encoding, CHUNKED_ENCODING);
    test::eq(res.headers.via, "1.1 Caddy");

    // TODO: For some reason, its turning upper case letters into lower case
    // TODO: Also for some reason, this is not picking up the first char of "{"
    test::@check(res.body.contains("\"key\":"));
}

fn void test_ok_chunked_1() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "access-control-allow-origin: *\r\n",
      "content-type: application/json \r\n",
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n",
      "via: 1.1 Caddy \r\n",
      "transfer-encoding: chunked",

      // Headers and Body separator
      CRLF,

      "4\r\n",
      "Wiki\r\n",
      "5\r\n",
      "pedia\r\n",
      "0\r\n",

      CRLF_END,
    };

    Response res = get_response(&input)!!;
    test::@check(res.body.contains("wiki"));
    test::@check(res.body.contains("pedia"));
}

struct Tmp
{
    Allocator alloc;
    Mutex* mtx;
    ConditionVariable* cond;
    int ready;
    bool done;

    // TODO: Does this need ot be a pointer? by copying the file descriptor...
    // is it the same file descriptor?
    TcpSocket* tx;
}

fn void worker_thread(Tmp* tmp)
{
    // TODO: The threading issue was tora! its not thread safe.
    io::printn("\n!!!!DEBUG: Worker watiing for signal!!!!");
    while (!tmp.done)
    {

    io::printn("!!!!DEBUG: tmp.done while loop!!!!");
    // TODO: SOme issue with using a temp allocation.
    @pool_init(tmp.alloc, 1024)
    {
        tmp.mtx.@in_lock()
        {
            while (tmp.ready < 1 && !tmp.done) {
                io::printn("!!!!DEBUG: worker waiting in while loop!!!!");
                tmp.cond.wait(tmp.mtx)!!;
            }

            io::printfn("!!!!DEBUG: Worker: is tmp.done true: %s !!!!", tmp.done);
            if (tmp.done) return;

            io::printn("!!!!DEBUG: Worker: outside of read < 1 loop!!!!");
            io::printfn("!!!!DEBUG: Worker: got the signal: %s!!!!", tmp.ready);

            String[*] delayed_chunk =
            {
              "5\r\n",
              "pedia\r\n",
              "0\r\n",

              CRLF_END,
            };

            DString chunk;
            chunk.init(tmp.alloc);
            defer chunk.free();

            foreach (&str : delayed_chunk) chunk.appendf(*str);
            io::printfn("!!!!DEBUG: Worker: got writing the chunk to tx!!!!");
            tmp.tx.write(chunk.str_view())!!;

            tmp.ready = 0;
            tmp.done = true;
        };
    };
    }
}

fn void shutdown(Tmp* tmp, Thread* thread)
{

    tmp.done = true;
    tmp.cond.signal()!!;
    thread.join()!!;
}


fn void test_delayed_chunk_0() @test
{
    String[*] input =
    {
      "HTTP/1.1 200 OK \r\n",
      "access-control-allow-origin: *\r\n",
      "content-type: application/json \r\n",
      "date: Sat, 16 Aug 2025 21:48:49 GMT\r\n"
      "vary: Accept-Encoding \r\n",
      "via: 1.1 Caddy \r\n",
      "transfer-encoding: chunked",

      // Headers and Body separator
      CRLF,

      "4\r\n",
      "Wiki\r\n",
    };

    DString in = dstring::temp();
    foreach (&str : input) in.appendf(*str);

    TcpSocket tx; TcpSocket rx;
    socket_pair()!!.unpack(&tx, &rx);

    tx.write(in.str_view())!!;

    Mutex mtx;
    mtx.init()!!;

    ConditionVariable cond;
    cond.init()!!;

    Allocator alloc = allocator::heap();
    Tmp tmp = { .alloc = alloc, .mtx = &mtx, .cond = &cond, .ready = 0, .done = false, .tx = &tx };

    Thread log_thread;
    log_thread.create((ThreadFn) &worker_thread, &tmp)!!;
    defer shutdown(&tmp, &log_thread);

    mtx.@in_lock()
    {
        tmp.ready = 1;
        cond.signal()!!;
    };

    Response first_res = recv(rx)!!;
    test::@check(first_res.body.contains("wiki"));

    // Allow time to write to the socket.
    thread::sleep_ms(1000);

    test::@check(first_res.body.contains("pedia"));
    test::@check(!first_res.body.contains("not contains"));
}

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

struct TestThreadHarness
{
    Mutex mtx;
    ConditionVariable* cond;
    int ready;
    TcpSocket tx;
    String delayed_chunk;
}

fn void TestThreadHarness.init(&self, TcpSocket tx, String delayed_chunk)
{
    Mutex mtx;
    mtx.init()!!;

    ConditionVariable cond;
    cond.init()!!;

    *self = { .mtx = mtx, .cond = &cond, .ready = 0, .tx = tx, .delayed_chunk = delayed_chunk };
}

fn void worker_thread(TestThreadHarness* test_harness)
{
    test_harness.mtx.@in_lock()
    {
        while (!test_harness.ready) {
            test_harness.cond.wait(&test_harness.mtx)!!;
        }

        // Simulate a delayed chunk.
        thread::sleep_ms(1000);

        test_harness.tx.write(test_harness.delayed_chunk)!!;
    };
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

    DString first_chunk = dstring::temp();
    foreach (&str : input) first_chunk.appendf(*str);

    TcpSocket tx; TcpSocket rx;
    socket_pair()!!.unpack(&tx, &rx);

    tx.write(first_chunk.str_view())!!;

    String delayed_chunk = "5\r\npedia\r\n0\r\n".concat(tmem, CRLF_END);

    TestThreadHarness test_harness;
    test_harness.init(tx, delayed_chunk);

    Thread test_thread;
    test_thread.create((ThreadFn) &worker_thread, &test_harness)!!;
    defer test_thread.join()!!;

    test_harness.mtx.@in_lock()
    {
        test_harness.ready = 1;
        test_harness.cond.signal()!!;
    };

    Response res = recv(rx)!!;
    test::@check(res.body.contains("wiki"));
    test::@check(res.body.contains("pedia"));
}

module req;
import std::collections;

import std::collections::list;

fn void test_clrf_state_0() @test
{
    char[] input = { '\r', '\n', '\r', '\n' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    test::eq(state, CRLFState.END);
}

fn void test_clrf_state_1() @test
{
    char[] input = { '\r', '\n', '\n' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    test::eq(state, CRLFState.START);
}

fn void test_clrf_state_2() @test
{
    char[] input = { '0' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    test::eq(state, CRLFState.START);
}

fn void test_clrf_state_3() @test
{
    char[] input = { '\r', '\r' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    test::eq(state, CRLFState.START);
}

fn void test_clrf_state_4() @test
{
    char[] input = { '\r', '\n', '\r', '0', '\n', '\r', '\n', '\r', '\n', '0' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    test::eq(state, CRLFState.END);
}

fn void test_step_state_machine_index_0() @test
{
    char[] input = { '\r', '\n', '\r', '0', '\n', '\r', '\n', '\r', '\n', '0' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLF_Result pair = internal_state_machine(&buf);
    test::eq(pair.first, 8);
    test::eq(pair.second, CRLFState.END);
}

fn void test_step_state_machine_index_1() @test
{
    char[] input = { '\r', '\r' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLF_Result pair = internal_state_machine(&buf);
    test::eq(pair.first, 0);
    test::eq(pair.second, CRLFState.START);
}

fn void test_step_state_machine_index_2() @test
{
    char[] input = { '\r', '\n', '\r', '\n' };
    List{char} buf;
    buf.tinit_with_array(input);

    CRLFState state = step_state_machine(&buf);
    CRLF_Result pair = internal_state_machine(&buf);

    test::eq(pair.first, 3);
    test::eq(pair.second, CRLFState.END);
}

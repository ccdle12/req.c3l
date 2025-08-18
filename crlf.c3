module req;

import std::collections;

alias CRLF_Result = Pair{usz, CRLFState};

// TODO: Make this CRLFHeaderState or some how combine the two?
enum CRLFState
{
    START,
    CR,
    CRLF,
    CRLF_CR,
    END,
}

// TODO: Condition to make sure buf pointer is not null
fn CRLFState step_state_machine(List{char}* buf)
{
    return internal_state_machine(buf).second;
}

fn usz step_state_machine_with_index(List{char}* buf)
{
    return internal_state_machine(buf).first;
}

// TODO: Condition to make sure buf pointer is not null
// Also make it clear its the last position of CRLF
fn CRLF_Result internal_state_machine(List{char}* buf) @private
{
    CRLFState state = START;
    usz index;
    foreach (i, &c : buf)
    {

        switch(state)
        {
            case START:
                if (*c == '\r') state = CR;
                break;
            case CR:
                state = (*c == '\n') ? CRLF : START;
                break;
            case CRLF:
                state = (*c == '\r') ? CRLF_CR : START;
                break;
            case CRLF_CR:
                state = (*c == '\n') ? state = END : START;
                break;
            case END:
                break;
        }

        if (state == END)
        {
            index = i;
            break;
        }
    }

    return { .first = index, .second = state };
}

alias CRLF_Body_Result = Pair{usz, CRLFBodyState};

enum CRLFBodyState
{
    ZERO,
    START,
    CR,
    CRLF,
    CRLF_CR,
    END,
}

// TODO: Condition to make sure buf pointer is not null
// Also make it clear its the last position of CRLF
fn CRLF_Body_Result step_crlf_body(List{char}* buf)
{
    CRLFBodyState state = ZERO;
    usz index;
    foreach (i, &c : buf)
    {

        switch(state)
        {
            case ZERO:
                if (*c == '0') state = START;
                break;
            case START:
                if (*c == '\r') state = CR;
                break;
            case CR:
                state = (*c == '\n') ? CRLF : START;
                break;
            case CRLF:
                state = (*c == '\r') ? CRLF_CR : START;
                break;
            case CRLF_CR:
                state = (*c == '\n') ? state = END : START;
                break;
            case END:
                break;
        }

        if (state == END)
        {
            index = i;
            break;
        }
    }

    return { .first = index, .second = state };
}

fn usz? find_end_of_crlf(DString* dyn_buf)
{
    return dyn_buf.str_view().index_of("\r\n\r\n") + 4;
}

fn bool contains_crlf(DString* dyn_buf)
{
 return dyn_buf.str_view().contains(CRLF);
}

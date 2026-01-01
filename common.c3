module req;

import std::core::ascii;

<*
  Checks for valid characters allowed for HTTP Header keys.
*>
fn bool is_tchar(char c)
{
    if (ascii::@is_alnum(c)) return true;

    // Checks for allow special characters.
    if (
        c == '!' || // 33
        (c >= '#' && c <= '\'') || // 35-39: #, $, %, &, '
        c == '*' || // 42
        c == '+' || // 43
        c == '-' || // 45
        c == '.' || // 46
        c == '^' || // 94
        c == '_' || // 95
        c == '`' || // 96
        c == '|' || // 124
        c == '~'    // 126
    )
    {
        return true;
    }

    return false;
}

// TODO: Maybe remvoe all of this or make it just return error.
<*
  Common function to handle a CR when stepping in the parsers.
*>
fn void? handle_cr(char c, usz* read_idx) => handle_crlf('\r', c, read_idx)!;

<*
  Common function to handle an LF when stepping in the parsers.
*>
fn void? handle_lf(char c, usz* read_idx) => handle_crlf('\n', c, read_idx)!;

<*
  Internal function for both cr and lf.
*>
fn void? handle_crlf(char target, char c, usz* read_idx) @private
{
    if (c != target) return MALFORMED_CRLF?;
    (*read_idx)++;
    return;
}

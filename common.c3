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

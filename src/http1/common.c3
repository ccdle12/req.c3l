module req::http1;

import std::core::ascii;

const char CR = '\r';
const char LF = '\n';
const char SP = ' ';

faultdef MALFORMED_CRLF;

enum HttpParserResult
{
    REQUEST_MORE,
    COMPLETE,
}

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

<*
  Common function to handle an LF when stepping in the parsers.
*>
fn void? assert_lf(char c)
{
    if (c != LF) return MALFORMED_CRLF?;
}

<*
  Common function to handle an CR when stepping in the parsers.
*>
fn void? assert_cr(char c)
{
    if (c != CR) return MALFORMED_CRLF?;
}

fn String normalize_key(Allocator allocator, String key) => key.trim().to_lower_copy(allocator);
fn String tnormalize_key(String key) => key.trim().to_lower_tcopy();

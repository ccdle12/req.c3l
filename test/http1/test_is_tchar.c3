module req::http1;

fn void test_valid_tchar() @test
{
    // Test for all valid 0-9
    for (char i = '0'; i < '9'; i++)
    {
        test::@check(is_tchar(i));
    }

    // Test for all valid A-Z
    for (char i = 'A'; i < 'Z'; i++)
    {
        test::@check(is_tchar(i));
    }

    // Test for all valid a-z
    for (char i = 'a'; i < 'z'; i++)
    {
        test::@check(is_tchar(i));
    }

    // Test for all valid special symbols
    char[] special_symbols = "!#$%&'*+-.^_`|~";
    foreach(symbol : special_symbols)
    {
        test::@check(is_tchar(symbol));
    }

    // Test for all known invalid symbols.
    char[] invalid_symbols = {':', ';', '<', '=', '>', '?', '@', '[', ']', '{', '}'};
    foreach(invalid : invalid_symbols)
    {
        test::@check(!is_tchar(invalid));
    }

    // Test for escape character
    test::@check(!is_tchar(92));
}

module req::http1;

import std::io;

fn void test_validate_http_date_time() @test
{
    test::@check(validate_http_date_time("Wed, 23-Nov-2011 01:05:03 GMT")!!);
}

fn void test_invalid_http_date_time() @test
{
    String[*] inputs = {
        "Wed,23-Nov-201101:05:03GMT", // no whitespace
        "Wed, 23-Nov-2011 01:05:03GMT",
        "",
        "Wed",
        "Wed 23-Nov-2011 01:05:03 GMT", // missing comma
        "Wed, 32-Nov-2011 01:05:03 GMT", // invalid date
        "Wed, 30-foo-2011 01:05:03 GMT",
        "Wed, 30-Nov-foo 01:05:03 GMT",
        "Wed, 30-Nov-2011 24:05:03 GMT", // invalid time
        "Wed, 30-Nov-2011 01:60:03 GMT",
        "Wed, 30-Nov-2011 01:00:60 GMT",
        "Wed, 30-Nov-2011 01:00:00 EST", // invalid timezone
        "Wed, 31-Apr-2011 01:00:00 GMT", // invalid last date for month
        "Wed, 29-Feb-2011 01:00:00 GMT",
    };

    foreach (input : inputs) test::@check(!validate_http_date_time(input)!!);
}

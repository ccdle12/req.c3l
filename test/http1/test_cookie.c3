module req::http1;

fn void test_cookie_from_str() @test
{
    Cookie cookie;
    cookie.tinit();

    String input = "cookie-1=one;";
    cookie.parse_str(input)!!;

    test::eq(cookie.name, "cookie-1");
    test::eq(cookie.value, "one");
}

fn void test_cookie_missing_name() @test
{
    Cookie cookie;
    cookie.tinit();

    String input = "flag;";
    test::@check(@catch(cookie.parse_str(input)));
}

fn void test_cookie_multiple_values() @test
{
    Cookie cookie;
    cookie.tinit();

    String input = "NID=99=YsDT5i3E-CXax-; expires=Wed, 23-Nov-2011 01:05:03 GMT; path=/; domain=.google.ch; HttpOnly; Max-Age=3600; Secure; SameSite=Strict";
    cookie.parse_str(input)!!;

    test::eq(cookie.name, "NID");
    test::eq(cookie.value, "99=YsDT5i3E-CXax-");
    test::eq(cookie.path, "/");
    test::eq(cookie.domain, ".google.ch");
    test::eq(cookie.expires_raw, "Wed, 23-Nov-2011 01:05:03 GMT");
    test::eq(cookie.max_age, 3600);
    test::@check(cookie.secure);
    test::@check(cookie.http_only);
    test::eq(cookie.same_site, SameSite.STRICT);
}

// Not including a ; at the end is considered valid.
fn void test_single_cookie_attribute() @test
{
    Cookie cookie;
    cookie.tinit();

    cookie.parse_str("cookie=attribute")!!;
    test::eq(cookie.name, "cookie");
    test::eq(cookie.value, "attribute");
}

fn void test_incomplete_cookie_name() @test
{
    Cookie cookie;
    cookie.tinit();

    test::eq(@catch(cookie.parse_str("cookie")), MALFORMED_COOKIE_MISSING_NAME);

}

fn void test_invalid_cookie_name_chars() @test
{
    Cookie cookie;
    cookie.tinit();

    String[*] test_inputs = {
                                "cook,ie=attribute;",
                                "cooki;ie=attribute;",
                                "cooki ie=attribute;",
                                "cookie =attribute;",
                                "cook\rie=attribute;",
                                "cook\nie=attribute;",
                                "coo:nie=attribute;",
                            };

    foreach (&input : test_inputs)
    {
        test::eq(@catch(cookie.parse_str(*input)), MALFORMED_COOKIE_INVALID_CHAR);
    }
}

fn void test_invalid_cookie_attribute() @test
{
    Cookie cookie;
    cookie.tinit();

    String[*] test_inputs = {
                                "cookie=attribute second third",
                                "cookie=attribute,second,third",
                                "cookie=attribute; HttpOnly; domain=www.hello,foo .com",
                            };

    foreach (&input : test_inputs)
    {
        test::eq(@catch(cookie.parse_str(*input)), MALFORMED_COOKIE_INVALID_CHAR);
    }
}

fn void test_empty_cookie() @test
{

    Cookie cookie;
    cookie.tinit();

    test::eq(@catch(cookie.parse_str("")), MALFORMED_EMPTY_COOKIE);
}

fn void test_cookie_with_quotations() @test
{

    Cookie cookie;
    cookie.tinit();

    cookie.parse_str("cookie=\"atrribute\";")!!;
    test::eq(cookie.name, "cookie");
    test::eq(cookie.value, "\"atrribute\"");

    cookie.parse_str("cookie=\"atrribute second third\";")!!;
    test::eq(cookie.name, "cookie");
    test::eq(cookie.value, "\"atrribute second third\"");

    cookie.parse_str("cookie=\"atrribute,second,third\";")!!;
    test::eq(cookie.name, "cookie");
    test::eq(cookie.value, "\"atrribute,second,third\"");
}

fn void test_multiple_cookie_attributes_with_quotation() @test
{
    Cookie cookie;
    cookie.tinit();

    cookie.parse_str("cookie=\"atrribute\"; HttpOnly; domain=\"www.hello,foo .com\"")!!;
    test::eq(cookie.domain, "\"www.hello,foo .com\"");
}

fn void test_invalid_same_site_values() @test
{
    Cookie cookie;
    cookie.tinit();

    String[*] test_inputs = {
                                "cookie=foo; SameSite=foo",
                                "cookie=foo; SameSite=DEFAULT",
                            };

    foreach (&input : test_inputs)
    {
        test::eq(@catch(cookie.parse_str(*input)), MALFORMED_COOKIE_INVALID_SAMESITE);
    }
}

fn void test_valid_same_site_values() @test
{
    Cookie cookie;
    cookie.tinit();

    cookie.parse_str("cookie=attribute; SameSite=Lax")!!;
    test::eq(cookie.name, "cookie");
    test::eq(cookie.value, "attribute");

    cookie.parse_str("cookie=attribute; SameSite=Strict")!!;
    test::eq(cookie.same_site, SameSite.STRICT);

    cookie.parse_str("cookie=attribute; SameSite=strict")!!;
    test::eq(cookie.same_site, SameSite.STRICT);
}

fn void test_none_requirement_with_secure_flag() @test
{
    Cookie cookie;
    cookie.tinit();

    test::eq(@catch(cookie.parse_str("cookie=attribute; SameSite=none")), MALFORMED_COOKIE_MISSING_SECURE_FLAG);

}

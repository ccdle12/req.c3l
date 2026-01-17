module req::http1;

import std::io;
import std::time;

enum SameSite : (String name)
{
    // Cookies are only sent in the first party context, will not be included
    // in third party requests.
    STRICT = "strict",

    // The default value, cookies are sent with top-level navigation to the site
    // but cookies will not be sent with other types of cross-origin requests.
    LAX = "lax",

    // Cookies are sent in all contexts, allows cross-site cookie access but
    // MUST have the secure flag set in the Cookie.
    NONE = "none",
}

fn SameSite? same_site_from_str(String input)
{
    if (SameSite.STRICT.name == tnormalize_key(input)) return STRICT;
    if (SameSite.LAX.name == tnormalize_key(input))    return LAX;
    if (SameSite.NONE.name   == tnormalize_key(input)) return NONE;

    return MALFORMED_COOKIE_INVALID_SAMESITE?;
}

faultdef MALFORMED_COOKIE_MISSING_NAME,
         MALFORMED_COOKIE_INVALID_CHAR,
         MALFORMED_EMPTY_COOKIE,
         MALFORMED_COOKIE_INVALID_SAMESITE,
         MALFORMED_COOKIE_MISSING_SECURE_FLAG,
         MALFORMED_COOKIE_INVALID_EXPIRY_DATE;

struct Cookie
{
    Allocator allocator;

    // Cookie identifier - must appear first.
    String name;

    // Cookie value.
    String value;

    // The max time the cookie is valid for.
    uint max_age;

    // The domain where the cookie is used - optional.
    String domain;

    // The path where the cookie is sent - optional.
    String path;

    // TODO: - Whats the difference between expires and max_age?
    String expires_raw;
    DateTime expires;
    // TODO: - Create a date time object for expires.

    // The cookie must only be sent over HTTPS - optional.
    bool secure;

    // Prevents client side scripts from accessing the cookie - optional.
    bool http_only;

    // Sets rules limiting browsers from forwarding this cookie with cross-site requests.
    SameSite same_site;
}

fn void Cookie.init(&self, Allocator allocator) => self.allocator = allocator;
fn void Cookie.tinit(&self) => self.init(tmem);

fn void Cookie.clear(&self)
{
    self.name = "";
    self.value = "";
    self.max_age = 0;
    self.domain = "";
    self.path = "";
    self.expires_raw = "";
    self.secure = false;
    self.http_only = false;
    // TODO: Is this correct? - should I set a null variant?
    self.same_site = SameSite.LAX;
}

fn void? Cookie.parse_str(&self, String value) => @pool()
{
    if (value.len < 1) return MALFORMED_EMPTY_COOKIE?;

    // Clear the previous values when we overwrite a cookie.
    self.clear();

    self.validate_pre_split_cookie_name(value)!;

    String[] cookie_attributes = value.tsplit(";");
    String[] cookie_name_and_value = cookie_attributes[0].trim().tsplit("=", 2);

    if (cookie_name_and_value.len < 2) return MALFORMED_COOKIE_MISSING_NAME?;

    String cookie_name = cookie_name_and_value[0];
    String cookie_attribute = cookie_name_and_value[1];

    foreach (c : cookie_name) if (!is_tchar(c)) return MALFORMED_COOKIE_INVALID_CHAR?;

    // Check that the cookie name attribute only allows " " and ";" within quoted values.
    self.validate_non_quotation_attribute(cookie_attribute)!;

    // Assign the cookie name and its value.
    self.name  = cookie_name.copy(self.allocator);
    self.value = cookie_attribute.copy(self.allocator);

    // Parse the rest of the cookie attributes.
    foreach (&attribute : cookie_attributes[1..cookie_attributes.len-1])
    {
        String[] split_attribute = attribute.trim().tsplit("=", 2);
        String key = split_attribute[0];

        foreach (c : key) if (!is_tchar(c)) return MALFORMED_COOKIE_INVALID_CHAR?;

        // Parse Flags
        if (split_attribute.len < 2)
        {
            if (tnormalize_key(key) == "httponly") self.http_only = true;
            if (tnormalize_key(key) == "secure")   self.secure = true;
        }
        else
        {
            String attr = split_attribute[1];

            // Expires is the only exception where the attributes can have a " "
            // and "," without quotations.
            if (!(tnormalize_key(key) == "expires"))
            {
                self.validate_non_quotation_attribute(attr)!;
            }

            // Parse KV pairs
            if (tnormalize_key(key) == "path")
            {
                self.path = attr.trim().copy(self.allocator);
            }

            if (tnormalize_key(key) == "domain")
            {
                self.domain = attr.trim().copy(self.allocator);
            }

            if (tnormalize_key(key) == "expires")
            {
                self.expires_raw = attr.trim().copy(self.allocator);
                self.expires = parse_and_get_date_time(self.expires_raw) ?? MALFORMED_COOKIE_INVALID_EXPIRY_DATE?!;

            }

            if (tnormalize_key(key) == "max-age")
            {
                self.max_age = attr.to_integer(uint)!;
            }

            if (tnormalize_key(key) == "samesite")
            {

                self.same_site = same_site_from_str(attr)!;
            }
        }
    }

    // Having same_site as None and secure not set is not allowed.
    if (self.same_site == SameSite.NONE && self.secure == false)
    {
        return MALFORMED_COOKIE_MISSING_SECURE_FLAG?;
    }
}

// First check if the cookie name contains an invalid ';' in its name before
// splitting.
fn void? Cookie.validate_pre_split_cookie_name(&self, String value) @private @inline
{
    usz first_delimiter = 0;
    for (usz i = 0; i < value.len; i++)
    {
        if (value[i] == ';')
        {
            first_delimiter = i;
            break;
        }
    }

    if (first_delimiter > 0)
    {
        bool found_second_delimiter = false;
        for (usz i = 0; i < first_delimiter; i++)
        {
            if (value[i] == '=') found_second_delimiter = true;
        }

        // The input had a `;` in the middle of the cookie name.
        if (!found_second_delimiter) return MALFORMED_COOKIE_INVALID_CHAR?;
    }

}

fn void? Cookie.validate_non_quotation_attribute(&self, String attribute) @private @inline
{
    if (attribute.contains("\"")) return;

    if (attribute.contains(" ") || attribute.contains(","))
    {
        return MALFORMED_COOKIE_INVALID_CHAR?;
    }
}

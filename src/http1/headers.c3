module req::http1;

import std::collections::list;
import std::collections::map;
import std::collections::set;

faultdef MALFORMED_HEADER_DUPLICATE_SINGLETON,
         INVALID_HEADER_KEY_SYMBOL,
         INVALID_TRAILING_SPACE;

// Header Special Case Keys.
const String CONTENT_LENGTH_KEY = "content-length";
const String TRANSFER_ENCODING_KEY = "transfer-encoding";

// Cookie Header.
const String SET_COOKIE = "set-cookie";

// Header Singleton Keys.
const String AUTHORIZATION_KEY = "authorization";
const String CONTENT_LOCATION_KEY = "content-location";
const String CONTENT_RANGE_KEY = "content-range";
const String CONTENT_TYPE_KEY = "content-type";
const String DATE_KEY = "date";
const String ETAG_KEY = "etag";
const String FROM_KEY = "from";
const String HOST_KEY = "host";
const String IF_MODIFIED_SINCE_KEY = "if-modified-since";
const String IF_RANGE_KEY = "if-range";
const String IF_UNMODIFIED_SINCE_KEY = "if-unmodified-since";
const String LAST_MODIFIED_KEY = "last-modified";
const String LOCATION_KEY = "location";
const String MAX_FORWARDS_KEY = "max-forwards";
const String RANGE_KEY = "range";
const String REFERER_KEY = "referer";
const String RETRY_AFTER_KEY = "retry-after";
const String SERVER_KEY = "server";
const String USER_AGENT_KEY = "user-agent";

fn HashSet{String} get_special_case_headers(Allocator allocator)
{
    HashSet{String} special_cases;
    special_cases.init_with_values(allocator,
                                   CONTENT_LENGTH_KEY,
                                   TRANSFER_ENCODING_KEY);
    return special_cases;
}

fn HashSet{String} get_singleton_headers_set(Allocator allocator)
{
    HashSet{String} singletons;
    singletons.init_with_values(allocator,
                                AUTHORIZATION_KEY,
                                CONTENT_LOCATION_KEY,
                                CONTENT_RANGE_KEY,
                                CONTENT_TYPE_KEY,
                                DATE_KEY,
                                ETAG_KEY,
                                FROM_KEY,
                                HOST_KEY,
                                IF_MODIFIED_SINCE_KEY,
                                IF_RANGE_KEY,
                                IF_UNMODIFIED_SINCE_KEY,
                                LAST_MODIFIED_KEY,
                                LOCATION_KEY,
                                MAX_FORWARDS_KEY,
                                RANGE_KEY,
                                REFERER_KEY,
                                RETRY_AFTER_KEY,
                                SERVER_KEY,
                                USER_AGENT_KEY);
    return singletons;
}

fn bool is_singleton_header_key(String key) => @pool()
{
    HashSet{String} singletons = get_singleton_headers_set(tmem);
    return singletons.contains(key);
}

fn bool is_special_case_header_key(String key) => @pool()
{
    HashSet{String} special_cases = get_special_case_headers(tmem);
    return special_cases.contains(key);
}

struct HttpHeaders
{
    Allocator allocator;
    DynamicArenaAllocator arena;

    LinkedHashMap{String, Cookie} cookies;
    LinkedHashMap{String, Header} headers;
}

fn void HttpHeaders.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.arena.init(self.allocator, DEFAULT_PAGE_SIZE);
    self.headers.init(self.allocator);
    self.cookies.init(self.allocator);
}

fn void HttpHeaders.free(&self)
{
    self.arena.free();
    self.headers.free();
    self.cookies.free();
}

fn Header*? HttpHeaders.get_ref(&self, String key) => @pool()
{
    return self.headers.get_ref(normalize_key(tmem, key));
}

fn bool HttpHeaders.has_key(&self, String key) => self.headers.has_key(key);

fn Header*? HttpHeaders.push_and_get_header_ref(&self, String header_key, String header_value)
{
    self.push(header_key, header_value)!;
    return self.get_ref(header_key);
}

fn void? HttpHeaders.set_cookie(&self, String cookie_value)
{
    Cookie cookie;
    cookie.init(&self.arena);
    cookie.parse_str(cookie_value)!;

    self.cookies.set(cookie.name, cookie);
}

<*
 Creates a new header while validating the header rules on header types (e.g. SINGLETON etc...).
 *>
fn void? HttpHeaders.push(&self, String header_key, String header_value) => @pool()
{
    Header header = self.new_header_and_enforce_rules(tmem, header_key, header_value)!;

    if (try cached_header = self.headers.get_ref(header.key))
    {
        // Enforcement of duplicate header value MUST use the pre-normalized header value.
        self.enforce_content_length_special_case(cached_header, header_value)!;

        String additional_value = header.values.get(0).copy(&self.arena);
        cached_header.push_value(additional_value);
    }
    else
    {
        Header arena_header = header.copy(&self.arena);
        self.headers.set(arena_header.key, arena_header);
    }
}

<*
 Creates a new header while validating the header rules on header types (e.g. SINGLETON etc...).
 *>
fn Header? HttpHeaders.new_header_and_enforce_rules(&self, Allocator allocator, String header_key, String header_value) @private
{
    Header header;
    header.init(allocator);
    header.set_header(header_key, header_value)!;

    self.enforce_duplicate_singleton_case(&header)!;

    return header;
}

<*
 Enforces the single-instance constraint implied by header semantics per RFC 9112 (HTTP/1.1) §5.3
 and related header field definitions — duplicate instances of headers that are not allowed to appear
 multiple times should be treated as malformed.
 *>
fn void? HttpHeaders.enforce_duplicate_singleton_case(&self, Header* header) @private
{
    if (header.type == SINGLETON && self.headers.has_key(header.key)) return MALFORMED_HEADER_DUPLICATE_SINGLETON?;
}

<*
 Validate duplicate Content-Length header values per RFC 9112 section 6.3 (and RFC 7230 §3.3.2 behavior),
 ensuring multiple Content-Length headers are either identical or rejected.
*>
fn void? HttpHeaders.enforce_content_length_special_case(&self, Header* header, String pre_normalized_value) @private
{
    if (header.key == CONTENT_LENGTH_KEY && pre_normalized_value != header.values.get(0))
    {
        return MALFORMED_DUPLICATE_CONTENT_LENGTH?;
    }
}

<*
 foreach iterator for the headers.
*>
macro HttpHeaders.@each_header(&self; @body(key, value))
{
    self.headers.@each(; String key, Header header)
    {
        @body(key, header);
    };
}

enum HeaderType
{
    SINGLETON,
    SPECIAL_CASE,
    // TODO: TMP until we really need to distinguish between comma-separated and multi line.
    MULTI_VALUE,
}

fn HeaderType get_header_type(String key)
{
    if (is_singleton_header_key(key))    return SINGLETON;
    if (is_special_case_header_key(key)) return SPECIAL_CASE;
    return MULTI_VALUE;
}

<*
 Represents an HTTP header field.

 Assumptions and ownership:

  - Each Header is allocated (and its strings/values are stored) in the Headers arena.
  - Headers owns the arena and is responsible for freeing/resetting it.
  - Header does not free its own allocated memory.
 *>
struct Header
{
    Allocator allocator;
    String key;
    List{String} values;
    HeaderType type;
}

fn void Header.init(&self, Allocator allocator)
{
    self.allocator = allocator;
    self.values.init(self.allocator);
}

fn void? Header.validate_header_key(&self, String key)
{
    if (key[key.len - 1] == SP) return INVALID_TRAILING_SPACE?;

    foreach(c : key)
    {
        if (!is_tchar(c)) return INVALID_HEADER_KEY_SYMBOL?;
    }
}

fn void? Header.set_header(&self, String key, String value)
{
    self.validate_header_key(key)!;
    self.key = normalize_key(self.allocator, key);
    self.push_value(value);
    self.type = get_header_type(self.key);
}

fn void Header.push_value(&self, String value) => self.values.push(value.trim().copy(self.allocator));

fn Header Header.copy(&self, Allocator allocator)
{
    Header copy;
    copy.init(allocator);

    copy.key = self.key.copy(allocator);
    foreach (&value : self.values)
    {
        String value_copy = value.copy(allocator);
        copy.values.push(value_copy);
    }
    copy.type = self.type;

    return copy;
}

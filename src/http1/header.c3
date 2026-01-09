module req::http1;

import std::collections::list;
import std::collections::set;

faultdef MALFORMED_HEADER_DUPLICATE_SINGLETON;

// Header Special Case Keys.
const String CONTENT_LENGTH_KEY = "content-length";
const String TRANSFER_ENCODING_KEY = "transfer-encoding";

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


enum HeaderType
{
    SINGLETON,
    SPECIAL_CASE,
}

<*
 Represents an HTTP header field.

 Assumptions and ownership:

  - Each Header is allocated (and its strings/values are stored) from the HttpResponse arena.
  - HttpResponse owns the arena and is responsible for freeing/resetting it.
  - Header does not free its own arena-allocated memory.
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
    self.key = self.normalize_key(key);
    self.values.push(value.trim().copy(self.allocator));

    if (is_singleton_header_key(self.key))    self.type = SINGLETON;
    if (is_special_case_header_key(self.key)) self.type = SPECIAL_CASE;
}

fn void Header.push_value(&self, String value)    => self.values.push(value.trim().copy(self.allocator));
fn String Header.normalize_key(&self, String key) => key.trim().to_lower_copy(self.allocator);

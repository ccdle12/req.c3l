# Req C3

## HTTP1

- Adheres to RFC 9112: https://www.rfc-editor.org/rfc/rfc9112

### Parsing Headers Checklist

Task,Governing RFC,Section

#### 1. Status Line, Line Termination and Structure

- [x] "Verify HTTP Version, Status Code, Separators (Status Line)",RFC 9112, 4.1. Status Line

```
Status-Line = HTTP-Version + SP + Status-Code + SP + Reason-Phrase + CRLF
```

- [x] HTTP-Version must correctly parse protocol version `HTTP/1.1`, RFC9112, 4.1.
- [x] Status Code must be valid 3 digits, non-digit characters or missing 3 digit character MUST return error, RFC 9110, 15
- [x] Status Code must be converted to an integer value for semantic use
- [x] Missing Status code MUST return error, RFC 723, 3.1.2
- [x] Status Code must not be looked up against a list of known status codes to allow flexibility for future codes, RFC 723, 3.1.2
- [x] Reason-Phrase Handling, the implementation should be robust enough to handle a missing Reason-Phrase or a Status-Line that ends after a status-code., RFC 9110, 4.1
- [x] Status Line Termination (CRLF),RFC 7230,3.5. Message Framing
- [x] Header Line Termination (CRLF),RFC 7230,3.5. Message Framing
- [x] End of Headers (\r\n\r\n),RFC 7230,3.1. General Formatting / 3.5. Message Framing

- [ ] Obsolete Folding (LWS) Rejection,RFC 7230,Appendix B. Obsolete Syntax / 3.2.4. Field Values

---,---,---

#### 2. Header Field-Name Validation (The tchar Rule)

- [x] Check for Invalid Characters (tchar Rule),RFC 7230,3.2.6. Token and Quoted-String

- [x] No Whitespace Between Header and Colon,RFC 9112, 5.4 Field Values

- [x] Case In-sensitivity of Header Name,RFC 7230,3.2. Header Fields

---,---,---

#### 3. Header Field-Value Validation

- [x] Optional Whitespace (OWS) after Colon Stripping,RFC 7230,3.2.4. Field Values
    - Basically remove any leading whitespace before the value and trailing whitespace at the end of the value

- [ ] Server MUST reject any headers with a trailing whitespace on the field name before the colon, RFC 9112, 5.1, Field Line Parsing

- [ ] Reject headers that contain CRLF in the fieldname, RFC 9112

- [ ] "Valid Characters in Value (VCHAR, obs-text)",RFC 9112, 5.3, Field Values

- [ ] Control Characters in Value,RFC 7230,3.2.4. Field Values

- [ ] Trailing Whitespace Stripping,RFC 7230,3.2.4. Field Values

- [ ] Prioritize Transfer-Encoding over Content-Length — RFC 7230 §3.3.3 (2014): "If a Transfer-Encoding header field is present and the chunked transfer coding is not the final encoding, the message framing is invalid. If Transfer-Encoding is present, Content-Length MUST be ignored."

---,---,---

#### 4. Duplicate and Mandatory Fields

- [ ] Identify & Handle Duplicates (Comma-Separated/Unique),RFC 7230,3.2.2. Field Order
- [ ] "Check Mandatory Fields (e.g., Content-Length syntax)",RFC 7230,3.3. Message Body / 3.3.2. Content-Length

---,---,---

## 5. Security and Robustness

- [ ] Limit Header Count / Size - 16KB?, Not in RFCs, N/A
- [ ] Handle Truncation,Not in RFCs,N/A

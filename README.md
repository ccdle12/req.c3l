# Req C3

## HTTP1

- Adheres to RFC 9112: https://www.rfc-editor.org/rfc/rfc9112

### Parsing Headers Checklist

Task,Governing RFC,Section

#### 1. Line Termination and Structure,,

- [x] "Verify HTTP Version, Status Code, Separators (Status Line)",RFC 7230,3.1. Status Line
- [ ] Status Line Termination (CRLF),RFC 7230,3.5. Message Framing
- [ ] Header Line Termination (CRLF),RFC 7230,3.5. Message Framing
- [ ] End of Headers (\r\n\r\n),RFC 7230,3.1. General Formatting / 3.5. Message Framing
- [ ] Obsolete Folding (LWS) Rejection,RFC 7230,Appendix B. Obsolete Syntax / 3.2.4. Field Values

---,---,---

#### 2. Header Field-Name Validation (The tchar Rule),,

- [x] Check for Invalid Characters (tchar Rule),RFC 7230,3.2.6. Token and Quoted-String

- [x] No Whitespace Before Colon,RFC 7230,3.2.4. Field Values

- [x] Case In-sensitivity of Header Name,RFC 7230,3.2. Header Fields

---,---,---

#### 3. Header Field-Value Validation,,

- [ ] Optional Whitespace (OWS) after Colon Stripping,RFC 7230,3.2.4. Field Values
- [ ] "Valid Characters in Value (VCHAR, obs-text)",RFC 7230,3.2.4. Field Values / Appendix B. Obsolete Syntax
- [ ] Control Characters in Value,RFC 7230,3.2.4. Field Values
- [ ] Trailing Whitespace Stripping,RFC 7230,3.2.4. Field Values

---,---,---

#### 4. Duplicate and Mandatory Fields,,

- [ ] Identify & Handle Duplicates (Comma-Separated/Unique),RFC 7230,3.2.2. Field Order
- [ ] "Check Mandatory Fields (e.g., Content-Length syntax)",RFC 7230,3.3. Message Body / 3.3.2. Content-Length

---,---,---

## 5. Security and Robustness,,

- [ ] Limit Header Count / Size,Not in RFCs,N/A
- [ ] Handle Truncation,Not in RFCs,N/A

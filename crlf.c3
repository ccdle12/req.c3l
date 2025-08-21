module req;

fn usz? find_end_of_crlf(DString* dyn_buf) => dyn_buf.str_view().index_of(CRLF) + 4;
fn bool contains_crlf(DString* dyn_buf) => dyn_buf.str_view().contains(CRLF) @inline;

///|
/// header_framer returns a new Framer.
/// The messages are sent with HTTP content length and MIME type headers.
/// This is the format used by LSP and others.
pub fn header_framer() -> &Framer {
  HeaderFramer::{  }
}

///|
pub struct HeaderFramer {}

///|
pub struct HeaderReader {
  in_ : &@io.ByteReader
}

///|
pub struct HeaderWriter {
  out : &@io.Writer
}

///|
pub impl Framer for HeaderFramer with reader(_self, in_) -> &Reader {
  HeaderReader::{ in_, }
}

///|
pub impl Framer for HeaderFramer with writer(_self, out) -> &Writer {
  HeaderWriter::{ out, }
}

///|
pub impl Reader for HeaderReader with read(self) -> (
  Message?,
  Int64,
  @io.IOError?,
) {
  let mut total = 0L
  let mut length = 0
  // read the header, stop on the first empty line
  for {
    let buf = @io.Buffer::new()
    let (n, err) = @io.copy_until(buf, self.in_, b'\n')
    total += n
    guard err is None else {
      return (
        None,
        total,
        Some(@io.IOError("failed reading header line: \{err}")),
      )
    }
    let line = buf.to_string().trim_space()
    // check we have a header line
    if line == "" {
      break
    }
    let colon = match line.find(":") {
      Some(c) => c
      None =>
        return (
          None,
          total,
          Some(@io.IOError("missing colon, invalid header line: '\{line}'")),
        )
    }
    let name = line.to_string().substring(end=colon)
    let value = line.to_string().substring(start=colon + 1).trim_space()
    // ignore unknown headers
    if name.to_lower() == "content-length" {
      length = try @strconv.parse_int!(value.to_string(), base=10) catch {
        _ =>
          return (
            None,
            total,
            Some(@io.IOError("failed parsing Content-Length: \{value}")),
          )
      }
      if length <= 0 {
        return (
          None,
          total,
          Some(@io.IOError("invalid Content-Length: \{length}")),
        )
      }
    }
  }
  if length == 0 {
    return (None, total, Some(@io.IOError("missing Content-Length header")))
  }
  let buf = @io.Buffer::new(size_hint=length)
  let (n, err) = @io.copy_size(buf, self.in_, length.to_int64())
  total += n
  guard err is None else {
    return (None, total, Some(@io.IOError("failed reading body: \{err}")))
  }
  let msg : Message = try @json.from_json!(@json.parse!(buf.to_string())) catch {
    e => return (None, 0, Some(@io.IOError(e.to_string())))
  }
  (Some(msg), n, None)
}

///|
pub impl Writer for HeaderWriter with write(self, msg) -> (Int64, @io.IOError?) {
  let s = msg.to_json().stringify()
  let body = @io.Buffer::new()
  let (body_total, err) = body.write_string(s)
  guard err is None else { return (0, err) }
  let hdr = @io.Buffer::new()
  let (_, err) = hdr.write_string("Content-Length: \{body_total}\r\n\r\n")
  guard err is None else { return (0, err) }
  let (hdr_total, err) = self.out.write(hdr.to_slice())
  guard err is None else { return (hdr_total.to_int64(), err) }
  let (n, err) = self.out.write(body.to_slice())
  guard err is None else { return (n.to_int64() + hdr_total.to_int64(), err) }
  (n.to_int64() + hdr_total.to_int64(), err)
}

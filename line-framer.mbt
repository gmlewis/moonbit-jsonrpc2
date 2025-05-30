///|
/// line_framer returns a new Framer.
/// The messages are sent with a terminating cr+newline, and rely on json decode consistency
/// to determine message boundaries.
pub fn line_framer() -> &Framer {
  LineFramer::{  }
}

///|
pub struct LineFramer {}

///|
pub struct LineReader {
  in_ : &@io.ByteReader
}

///|
pub struct LineWriter {
  out : &@io.Writer
}

///|
pub impl Framer for LineFramer with reader(_self, in_) -> &Reader {
  LineReader::{ in_, }
}

///|
pub impl Framer for LineFramer with writer(_self, out) -> &Writer {
  LineWriter::{ out, }
}

///|
pub impl Reader for LineReader with read(self) -> (
  Message?,
  Int64,
  @io.IOError?,
) {
  let buf = @io.Buffer::new()
  let (n, err) = @io.copy_until(buf, self.in_, b'\n')
  guard err is None else { return (None, 0, err) }
  let msg : Message = try
    // Are these conversions really necessary?
    @json.from_json!(@json.parse!(buf.to_string().trim_space().to_string())) catch {
    e => return (None, 0, Some(@io.IOError(e.to_string())))
  }
  (Some(msg), n, None)
}

///|
pub impl Writer for LineWriter with write(self, msg) -> (Int64, @io.IOError?) {
  let s = msg.to_json().stringify()
  let body = @io.Buffer::new()
  let (_, err) = body.write_string("\{s}\r\n")
  guard err is None else { return (0, err) }
  let (n, err) = self.out.write(body.to_slice())
  guard err is None else { return (n.to_int64(), err) }
  (n.to_int64(), err)
}

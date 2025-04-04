///| raw_framer returns a new Framer.
/// The messages are sent with no wrapping, and rely on json decode consistency
/// to determine message boundaries.
pub fn raw_framer() -> &Framer {
  RawFramer::{  }
}

///|
pub struct RawFramer {}

///|
struct RawReader {
  in_ : &@io.ByteReader
}

///|
struct RawWriter {
  out : &@io.Writer
}

///|
pub impl Framer for RawFramer with reader(_self, in_) -> &Reader {
  RawReader::{ in_, }
}

///|
pub impl Framer for RawFramer with writer(_self, out) -> &Writer {
  RawWriter::{ out, }
}

///|
pub impl Reader for RawReader with read(self) -> (Message?, Int64, @io.IOError?) {
  let (json, n, err) = @io.copy_json(self.in_)
  if err != None {
    return (None, n, err)
  }
  let msg : Message = try {
    @json.from_json!(json)
  } catch {
    e => return (None, n, Some(@io.IOError(e.to_string())))
  }
  (Some(msg), n, None)
}

///|
pub impl Writer for RawWriter with write(self, msg) -> (Int64, @io.IOError?) {
  let s = @json.stringify(msg.to_json())
  let body = @io.Buffer::new()
  let (_, err) = body.write_string(s)
  guard err is None else { return (0, err) }
  let (n, err) = self.out.write(body.to_slice())
  guard err is None else { return (n.to_int64(), err) }
  (n.to_int64(), err)
}

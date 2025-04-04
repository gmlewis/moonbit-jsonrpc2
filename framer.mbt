///| This file is based on: https://cs.opensource.google/go/x/exp/+/master:jsonrpc2/frame.go;bpv=0
/// which has copyright:
/// Copyright 2018 The Go Authors. All rights reserved.
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file.

///| Reader abstracts the transport mechanics from the JSON RPC protocol.
/// A Conn reads messages from the reader it was provided on construction,
/// and assumes that each call to Read fully transfers a single message,
/// or returns an error.
/// A reader is not safe for concurrent use, it is expected it will be used by
/// a single Conn in a safe manner.
pub trait Reader {
  // Read gets the next message from the stream.
  read(Self) -> (Message?, Int64, @io.IOError?)
}

///| Writer abstracts the transport mechanics from the JSON RPC protocol.
/// A Conn writes messages using the writer it was provided on construction,
/// and assumes that each call to Write fully transfers a single message,
/// or returns an error.
/// A writer is not safe for concurrent use, it is expected it will be used by
/// a single Conn in a safe manner.
pub trait Writer {
  // Write sends a message to the stream.
  write(Self, Message) -> (Int64, @io.IOError?)
}

///| Framer wraps low level byte readers and writers into jsonrpc2 message
/// readers and writers.
/// It is responsible for the framing and encoding of messages into wire form.
pub trait Framer {
  // Reader wraps a byte reader into a message reader.
  reader(Self, &@io.ByteReader) -> &Reader
  // Writer wraps a writer into a message writer.
  writer(Self, &@io.Writer) -> &Writer
}

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
  let buf = @io.Buffer::new()
  let (json, n, err) = buf.copy_json(self.in_)
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

///| header_framer returns a new Framer.
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
    let (n, err) = buf.copy_until(self.in_, b'\n')
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
    let colon = line.index_of(":")
    if colon < 0 {
      return (None, total, Some(@io.IOError("invalid header line: '\{line}'")))
    }
    let name = line.substring(end=colon)
    let value = line.substring(start=colon + 1).trim_space()
    // ignore unknown headers
    if name == "Content-Length" {
      length = try {
        @strconv.parse_int!(value, base=10)
      } catch {
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
  let buf = @io.Buffer::new()
  let (n, err) = buf.copy_size(self.in_, length)
  total += n
  guard err is None else {
    return (None, total, Some(@io.IOError("failed reading body: \{err}")))
  }
  let msg : Message = try {
    @json.from_json!(@json.parse!(buf.to_string()))
  } catch {
    e => return (None, 0, Some(@io.IOError(e.to_string())))
  }
  (Some(msg), n, None)
}

///|
pub impl Writer for HeaderWriter with write(self, msg) -> (Int64, @io.IOError?) {
  let s = @json.stringify(msg.to_json())
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

///| line_framer returns a new Framer.
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
  let (s, n, err) = buf.copy_until(self.in_, b'\n')
  guard err is None else { return (None, 0, err) }
  let msg : Message = try {
    @json.from_json!(@json.parse!(s))
  } catch {
    e => return (None, 0, Some(@io.IOError(e.to_string())))
  }
  (Some(msg), n, None)
}

///|
pub impl Writer for LineWriter with write(self, msg) -> (Int64, @io.IOError?) {
  let s = @json.stringify(msg.to_json())
  let body = @io.Buffer::new()
  let (_, err) = body.write_string("\{s}\r\n")
  guard err is None else { return (0, err) }
  let (n, err) = self.out.write(body.to_slice())
  guard err is None else { return (n.to_int64(), err) }
  (n.to_int64(), err)
}

///|
/// This file is based on: https://cs.opensource.google/go/x/exp/+/master:jsonrpc2/frame.go;bpv=0
/// which has copyright:
/// Copyright 2018 The Go Authors. All rights reserved.
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file.

///|
/// Reader abstracts the transport mechanics from the JSON RPC protocol.
/// A Conn reads messages from the reader it was provided on construction,
/// and assumes that each call to Read fully transfers a single message,
/// or returns an error.
/// A reader is not safe for concurrent use, it is expected it will be used by
/// a single Conn in a safe manner.
pub trait Reader {
  // Read gets the next message from the stream.
  read(Self) -> (Message?, Int64, @io.IOError?)
}

///|
/// Writer abstracts the transport mechanics from the JSON RPC protocol.
/// A Conn writes messages using the writer it was provided on construction,
/// and assumes that each call to Write fully transfers a single message,
/// or returns an error.
/// A writer is not safe for concurrent use, it is expected it will be used by
/// a single Conn in a safe manner.
pub trait Writer {
  // Write sends a message to the stream.
  write(Self, Message) -> (Int64, @io.IOError?)
}

///|
/// Framer wraps low level byte readers and writers into jsonrpc2 message
/// readers and writers.
/// It is responsible for the framing and encoding of messages into wire form.
pub trait Framer {
  // Reader wraps a byte reader into a message reader.
  reader(Self, &@io.ByteReader) -> &Reader
  // Writer wraps a writer into a message writer.
  writer(Self, &@io.Writer) -> &Writer
}

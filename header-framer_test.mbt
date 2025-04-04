///|
test "HeaderFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let raw_reader = header_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("failed reading header line: Some(IOError(\"eof\"))"))
    ,
  )
}

///|
test "HeaderFramer::read/missing-content-length" {
  let buffer = @io.Buffer::from_string("\n\n{not-a-json}")
  let raw_reader = header_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="1")
  inspect!(
    err,
    content=
      #|Some(IOError("missing Content-Length header"))
    ,
  )
}

///|
test "HeaderFramer::read/malformed-json" {
  let buffer = @io.Buffer::from_string("content-length: 12\n\n{not-a-json}")
  let raw_reader = header_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("Invalid character 'n' at line 1, column 1"))
    ,
  )
}

///|
test "HeaderFramer::read/bad-content-length" {
  let buffer = @io.Buffer::from_string(
    "Content-Length: 12\n\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\",\"params\":{}}",
  )
  let raw_reader = header_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("Unexpected end of file"))
    ,
  )
}

///|
test "HeaderFramer::read/valid-request" {
  let buffer = @io.Buffer::from_string(
    "Content-Length: 52\n\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\",\"params\":{}}content-length: 36\n\n{\"valid-json\":\"but-invalid-jsonrpc\"}content-Length: 13\r\n\r\n{extra-stuff}",
  )
  let raw_reader = header_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(
    msg,
    content=
      #|Some(Request({id: Some(Number(1)), method_: "test", params: Object({})}))
    ,
  )
  inspect!(n, content="52")
  inspect!(err, content="None")
  // read again to consume the valid JSON but invalid JSON-RPC
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("JsonDecodeError(($, \"expected request or response\"))"))
    ,
  )
  // read again to consume the invalid JSON
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("Invalid character 'e' at line 1, column 1"))
    ,
  )
}

///|
test "HeaderFramer::write/basic_functionality" {
  let buffer = @io.Buffer::new(size_hint=100)
  let writer = header_framer().writer(buffer)
  let msg = new_notification("test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="74")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}",
  )
  let msg = new_call(ID::number(100), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="83")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}",
  )
  let msg = new_call(ID::string("abc"), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="85")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}Content-Length: 63\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}",
  )
}

///|
test "LineFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let raw_reader = line_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("eof"))
    ,
  )
}

///|
test "LineFramer::read/missing-newline" {
  let buffer = @io.Buffer::from_string("{not-a-json}")
  let raw_reader = line_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("eof"))
    ,
  )
}

///|
test "LineFramer::read/malformed-json" {
  let buffer = @io.Buffer::from_string("{not-a-json}\n")
  let raw_reader = line_framer().reader(buffer)
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
test "LineFramer::read/valid-request" {
  let buffer = @io.Buffer::from_string(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\",\"params\":{}}\n{\"valid-json\":\"but-invalid-jsonrpc\"}\n{extra-stuff}\n",
  )
  let raw_reader = line_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(
    msg,
    content=
      #|Some(Request({id: Some(Number(1)), method_: "test", params: Object({})}))
    ,
  )
  inspect!(n, content="53")
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
test "LineFramer::write/basic_functionality" {
  let buffer = @io.Buffer::new(size_hint=100)
  let writer = line_framer().writer(buffer)
  let msg = new_notification("test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="54")
  inspect!(
    buffer.to_string(),
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n",
  )
  let msg = new_call(ID::number(100), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="63")
  inspect!(
    buffer.to_string(),
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n",
  )
  let msg = new_call(ID::string("abc"), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="65")
  inspect!(
    buffer.to_string(),
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}\r\n",
  )
}

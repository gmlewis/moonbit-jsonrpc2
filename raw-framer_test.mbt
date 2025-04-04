///|
test "RawFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let raw_reader = raw_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("invalid eof"))
    ,
  )
}

///|
test "RawFramer::read/malformed-json" {
  let buffer = @io.Buffer::from_string("{not-a-json}")
  let raw_reader = raw_framer().reader(buffer)
  let (msg, n, err) = raw_reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("invalid JSON: unexpected 'n' at offset 1"))
    ,
  )
}

///|
test "RawFramer::read/valid-request" {
  let buffer = @io.Buffer::from_string(
    #|{"jsonrpc":"2.0","id":1,"method":"test","params":{}}{"valid-json":"but-invalid-jsonrpc"}{extra-stuff}
    ,
  )
  let raw_reader = raw_framer().reader(buffer)
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
  inspect!(n, content="36")
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
      #|Some(IOError("invalid JSON: unexpected 'e' at offset 1"))
    ,
  )
}

///|
test "RawFramer::write/basic_functionality" {
  let buffer = @io.Buffer::new(size_hint=100)
  let writer = raw_framer().writer(buffer)
  let msg = new_notification("test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="52")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}
    ,
  )
  let msg = new_call(ID::number(100), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="61")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}{"jsonrpc":"2.0","method":"test_method","params":[],"id":100}
    ,
  )
  let msg = new_call(ID::string("abc"), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="63")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}{"jsonrpc":"2.0","method":"test_method","params":[],"id":100}{"jsonrpc":"2.0","method":"test_method","params":[],"id":"abc"}
    ,
  )
}

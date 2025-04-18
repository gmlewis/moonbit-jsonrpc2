///|
test "HeaderFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let reader = header_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = header_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = header_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = header_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
    "Content-Length: 52\n\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\",\"params\":{}}Content-length: 135\n\n[{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"test2\",\"params\":{\"test3\":\"test4\"}},{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"test5\",\"params\":[\"a\",\"b\",\"c\"]}]content-length: 36\n\n{\"valid-json\":\"but-invalid-jsonrpc\"}content-Length: 13\r\n\r\n{extra-stuff}",
  )
  let reader = header_framer().reader(buffer)
  let (msg, n, err) = reader.read()
  inspect!(
    msg,
    content=
      #|Some(Request({id: Some(Number(1)), method_: "test", params: Object({})}))
    ,
  )
  inspect!(n, content="52")
  inspect!(err, content="None")

  // read again to consume the valid batch request
  let (msg, n, err) = reader.read()
  inspect!(
    msg,
    content=
      #|Some(BatchRequest([{id: Some(Number(2)), method_: "test2", params: Object({"test3": String("test4")})}, {id: Some(Number(3)), method_: "test5", params: Array([String("a"), String("b"), String("c")])}]))
    ,
  )
  inspect!(n, content="135")
  inspect!(err, content="None")

  // read again to consume the valid JSON but invalid JSON-RPC
  let (msg, n, err) = reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="0")
  inspect!(
    err,
    content=
      #|Some(IOError("JsonDecodeError(($, \"expected request(s) or response(s)\"))"))
    ,
  )

  // read again to consume the invalid JSON
  let (msg, n, err) = reader.read()
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

  //
  let msg = new_call(ID::number(100), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="83")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}",
  )

  //
  let msg = new_call(ID::string("abc"), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="85")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}Content-Length: 63\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}",
  )

  //
  let msg = new_batch_request([
    new_call(ID::number(123), "test", { "test": 1 }.to_json()),
    new_call(ID::string("xyz"), "test2", Json::Null),
    new_response(ID::number(567), Ok(Json::Number(42.0))), // not a request - will be filtered out
    new_notification("test3", ["a", "b", "c"].to_json()),
  ])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}Content-Length: 63\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}Content-Length: 168\r\n\r\n[{\"jsonrpc\":\"2.0\",\"method\":\"test\",\"params\":{\"test\":1},\"id\":123},{\"jsonrpc\":\"2.0\",\"method\":\"test2\",\"id\":\"xyz\"},{\"jsonrpc\":\"2.0\",\"method\":\"test3\",\"params\":[\"a\",\"b\",\"c\"]}]",
  )
  inspect!(n, content="191")

  //
  let msg = new_batch_response([
    new_call(ID::number(123), "test", { "test": 1 }.to_json()), // not a response - will be filtered out
    new_response(ID::number(567), Ok(Json::Number(42.0))),
    new_call(ID::string("xyz"), "test2", Json::Null), // ditto
    new_response(
      ID::number(890),
      Err(WireError::{
        code: 123,
        message: "test4".to_string(),
        data: Some({ "test5": "test6" }.to_json()),
      }),
    ),
    new_notification("test3", ["a", "b", "c"].to_json()), // ditto
  ])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(
    buffer.to_string(),
    content="Content-Length: 52\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}Content-Length: 61\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}Content-Length: 63\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}Content-Length: 168\r\n\r\n[{\"jsonrpc\":\"2.0\",\"method\":\"test\",\"params\":{\"test\":1},\"id\":123},{\"jsonrpc\":\"2.0\",\"method\":\"test2\",\"id\":\"xyz\"},{\"jsonrpc\":\"2.0\",\"method\":\"test3\",\"params\":[\"a\",\"b\",\"c\"]}]Content-Length: 131\r\n\r\n[{\"jsonrpc\":\"2.0\",\"id\":567,\"result\":42},{\"jsonrpc\":\"2.0\",\"id\":890,\"error\":{\"code\":123,\"message\":\"test4\",\"data\":{\"test5\":\"test6\"}}}]",
  )
  inspect!(n, content="154")
}

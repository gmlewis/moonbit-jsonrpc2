///|
test "LineFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let reader = line_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = line_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = line_framer().reader(buffer)
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
test "LineFramer::read/valid-request" {
  let buffer = @io.Buffer::from_string(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\",\"params\":{}}\n[{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"test2\",\"params\":{\"test3\":\"test4\"}},{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"test5\",\"params\":[\"a\",\"b\",\"c\"]}]\r\n{\"valid-json\":\"but-invalid-jsonrpc\"}\n{extra-stuff}\n",
  )
  let reader = line_framer().reader(buffer)
  let (msg, n, err) = reader.read()
  inspect!(
    msg,
    content=
      #|Some(Request({id: Some(Number(1)), method_: "test", params: Object({})}))
    ,
  )
  inspect!(n, content="53")
  inspect!(err, content="None")

  // read again to consume the valid batch request
  let (msg, n, err) = reader.read()
  inspect!(
    msg,
    content=
      #|Some(BatchRequest([{id: Some(Number(2)), method_: "test2", params: Object({"test3": String("test4")})}, {id: Some(Number(3)), method_: "test5", params: Array([String("a"), String("b"), String("c")])}]))
    ,
  )
  inspect!(n, content="137")
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

  //
  let msg = new_call(ID::number(100), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="63")
  inspect!(
    buffer.to_string(),
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n",
  )

  //
  let msg = new_call(ID::string("abc"), "test_method", [])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="65")
  inspect!(
    buffer.to_string(),
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}\r\n",
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
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}\r\n[{\"jsonrpc\":\"2.0\",\"method\":\"test\",\"params\":{\"test\":1},\"id\":123},{\"jsonrpc\":\"2.0\",\"method\":\"test2\",\"id\":\"xyz\"},{\"jsonrpc\":\"2.0\",\"method\":\"test3\",\"params\":[\"a\",\"b\",\"c\"]}]\r\n",
  )
  inspect!(n, content="170")

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
    content="{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[]}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":100}\r\n{\"jsonrpc\":\"2.0\",\"method\":\"test_method\",\"params\":[],\"id\":\"abc\"}\r\n[{\"jsonrpc\":\"2.0\",\"method\":\"test\",\"params\":{\"test\":1},\"id\":123},{\"jsonrpc\":\"2.0\",\"method\":\"test2\",\"id\":\"xyz\"},{\"jsonrpc\":\"2.0\",\"method\":\"test3\",\"params\":[\"a\",\"b\",\"c\"]}]\r\n[{\"jsonrpc\":\"2.0\",\"id\":567,\"result\":42},{\"jsonrpc\":\"2.0\",\"id\":890,\"error\":{\"code\":123,\"message\":\"test4\",\"data\":{\"test5\":\"test6\"}}}]\r\n",
  )
  inspect!(n, content="133")
}

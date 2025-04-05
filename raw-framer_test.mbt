///|
test "RawFramer::read/empty-input" {
  let buffer = @io.Buffer::new()
  let reader = raw_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
  let reader = raw_framer().reader(buffer)
  let (msg, n, err) = reader.read()
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
    #|{"jsonrpc":"2.0","id":1,"method":"test","params":{}}[{"jsonrpc":"2.0","id":2,"method":"test2","params":{"test3":"test4"}},{"jsonrpc":"2.0","id":3,"method":"test5","params":["a","b","c","Hello, 世界! 🌍"]}]{"valid-json":"but-invalid-jsonrpc"}{extra-stuff}
    ,
  )
  let reader = raw_framer().reader(buffer)
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
      #|Some(BatchRequest([{id: Some(Number(2)), method_: "test2", params: Object({"test3": String("test4")})}, {id: Some(Number(3)), method_: "test5", params: Array([String("a"), String("b"), String("c"), String("Hello, 世界! 🌍")])}]))
    ,
  )
  inspect!(n, content="157")
  inspect!(err, content="None")

  // read again to consume the valid JSON but invalid JSON-RPC
  let (msg, n, err) = reader.read()
  inspect!(msg, content="None")
  inspect!(n, content="36")
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

  //
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

  //
  let msg = new_call(ID::string("abc"), "test_method", ["Hello, 世界! 🌍"])
  let (n, err) = writer.write(msg)
  inspect!(err, content="None")
  inspect!(n, content="84")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}{"jsonrpc":"2.0","method":"test_method","params":[],"id":100}{"jsonrpc":"2.0","method":"test_method","params":["Hello, 世界! 🌍"],"id":"abc"}
    ,
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
  inspect!(n, content="182")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}{"jsonrpc":"2.0","method":"test_method","params":[],"id":100}{"jsonrpc":"2.0","method":"test_method","params":["Hello, 世界! 🌍"],"id":"abc"}[{"jsonrpc":"2.0","method":"test","params":{"test":1},"id":123},{"jsonrpc":"2.0","method":"test2","params":null,"id":"xyz"},{"jsonrpc":"2.0","method":"test3","params":["a","b","c"]}]
    ,
  )

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
  inspect!(n, content="131")
  inspect!(
    buffer.to_string(),
    content=
      #|{"jsonrpc":"2.0","method":"test_method","params":[]}{"jsonrpc":"2.0","method":"test_method","params":[],"id":100}{"jsonrpc":"2.0","method":"test_method","params":["Hello, 世界! 🌍"],"id":"abc"}[{"jsonrpc":"2.0","method":"test","params":{"test":1},"id":123},{"jsonrpc":"2.0","method":"test2","params":null,"id":"xyz"},{"jsonrpc":"2.0","method":"test3","params":["a","b","c"]}][{"jsonrpc":"2.0","id":567,"result":42},{"jsonrpc":"2.0","id":890,"error":{"code":123,"message":"test4","data":{"test5":"test6"}}}]
    ,
  )
}

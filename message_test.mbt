///|
test "Message/new_notification" {
  let msg = new_notification("test", Json::Null)
  let json = msg.to_json()
  inspect!(
    json,
    content=
      #|Object({"jsonrpc": String("2.0"), "method": String("test")})
    ,
  )
  let got : Message = @json.from_json!(json)
  inspect!(
    got,
    content=
      #|Request({id: None, method_: "test", params: Null})
    ,
  )
}

///|
test "Message/new_call" {
  let msg = new_call(ID::number(123), "test", Json::Null)
  let json = msg.to_json()
  inspect!(
    json,
    content=
      #|Object({"jsonrpc": String("2.0"), "method": String("test"), "id": Number(123)})
    ,
  )
  let got : Message = @json.from_json!(json)
  inspect!(
    got,
    content=
      #|Request({id: Some(Number(123)), method_: "test", params: Null})
    ,
  )
}

///|
test "Message/new_response" {
  let msg = new_response(ID::string("xyz"), Ok(Json::Number(42.0)))
  inspect!(
    msg.to_json(),
    content=
      #|Object({"jsonrpc": String("2.0"), "id": String("xyz"), "result": Number(42)})
    ,
  )
  let msg = new_response(
    ID::number(567),
    Err(WireError::{ code: 123, message: "test".to_string(), data: None }),
  )
  let json = msg.to_json()
  inspect!(
    json,
    content=
      #|Object({"jsonrpc": String("2.0"), "id": Number(567), "error": Object({"code": Number(123), "message": String("test")})})
    ,
  )
  let got : Message = @json.from_json!(json)
  inspect!(
    got,
    content=
      #|Response({id: Number(567), result: Err({code: 123, message: "test", data: None})})
    ,
  )

  //
  let msg = new_response(
    ID::string("xyz"),
    Err(WireError::{
      code: 123,
      message: "test".to_string(),
      data: Some({ "test": 1 }.to_json()),
    }),
  )
  let json = msg.to_json()
  inspect!(
    json,
    content=
      #|Object({"jsonrpc": String("2.0"), "id": String("xyz"), "error": Object({"code": Number(123), "message": String("test"), "data": Object({"test": Number(1)})})})
    ,
  )
  let got : Message = @json.from_json!(json)
  inspect!(
    got,
    content=
      #|Response({id: String("xyz"), result: Err({code: 123, message: "test", data: Some(Object({"test": Number(1)}))})})
    ,
  )
}

///|
test "Message/new_batch_request" {
  let msg = new_batch_request([
    new_call(ID::number(123), "test", { "test": 1 }.to_json()),
    new_call(ID::string("xyz"), "test2", Json::Null),
    new_response(ID::number(567), Ok(Json::Number(42.0))), // not a request - will be filtered out
    new_notification("test3", ["a", "b", "c"].to_json()),
  ])
  inspect!(
    msg.to_json(),
    content=
      #|Array([Object({"jsonrpc": String("2.0"), "method": String("test"), "params": Object({"test": Number(1)}), "id": Number(123)}), Object({"jsonrpc": String("2.0"), "method": String("test2"), "id": String("xyz")}), Object({"jsonrpc": String("2.0"), "method": String("test3"), "params": Array([String("a"), String("b"), String("c")])})])
    ,
  )
  let got : Message = @json.from_json!(msg.to_json())
  inspect!(
    got,
    content=
      #|BatchRequest([{id: Some(Number(123)), method_: "test", params: Object({"test": Number(1)})}, {id: Some(String("xyz")), method_: "test2", params: Null}, {id: None, method_: "test3", params: Array([String("a"), String("b"), String("c")])}])
    ,
  )
}

///|
test "Message/new_batch_response" {
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
  inspect!(
    msg.to_json(),
    content=
      #|Array([Object({"jsonrpc": String("2.0"), "id": Number(567), "result": Number(42)}), Object({"jsonrpc": String("2.0"), "id": Number(890), "error": Object({"code": Number(123), "message": String("test4"), "data": Object({"test5": String("test6")})})})])
    ,
  )
  let got : Message = @json.from_json!(msg.to_json())
  inspect!(
    got,
    content=
      #|BatchResponse([{id: Number(567), result: Ok(Number(42))}, {id: Number(890), result: Err({code: 123, message: "test4", data: Some(Object({"test5": String("test6")}))})}])
    ,
  )
}

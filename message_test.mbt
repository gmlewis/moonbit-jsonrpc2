///|
test "Message/to_json" {
  let msg = new_call(ID::number(123L), "test", Json::Null)
  let json = msg.to_json()
  inspect!(
    json,
    content=
      #|Object({"jsonrpc": String("2.0"), "method": String("test"), "params": Null, "id": Number(123)})
    ,
  )
  let got : Message = @json.from_json!(json)
  inspect!(
    got,
    content=
      #|Request({id: Some(Number(123)), method_: "test", params: Null})
    ,
  )

  //
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

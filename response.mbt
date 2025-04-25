///|
/// Response is a Message used as a reply to a call Request.
/// It will have the same ID as the call it is a response to.
pub(all) struct Response {
  // id of the request this is a response to.
  id : ID
  // result is the content of the response or an error.
  result : Result[Json, WireError]
} derive(Show, Eq)

///|
/// WireError is a jsonrpc2 error message.
pub(all) struct WireError {
  code : Int
  message : String
  data : Json?
} derive(Show, Eq, FromJson, ToJson)

///|
pub impl ToJson for Response with to_json(self) {
  let obj = { "jsonrpc": "2.0".to_json() }
  match self.id {
    String(s) => obj["id"] = s.to_json()
    Number(n) => obj["id"] = n.to_double().to_json()
  }
  match self.result {
    Ok(result) => obj["result"] = result
    Err(err) => obj["error"] = err.to_json()
  }
  obj.to_json()
}

///|
pub impl @json.FromJson for Response with from_json(json, path) {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object"))
  }
  match obj {
    { "jsonrpc": String("2.0"), "id": Number(id), "result": result, .. } =>
      { id: Number(id.to_int64()), result: Ok(result) }
    { "jsonrpc": String("2.0"), "id": String(id), "result": result, .. } =>
      { id: String(id), result: Ok(result) }
    {
      "jsonrpc": String("2.0"),
      "id": Number(id),
      "error": {
        "code": Number(code),
        "message": String(message),
        "data": data,
        ..
      },
      ..
    } =>
      {
        id: Number(id.to_int64()),
        result: Err({ code: code.to_int(), message, data: Some(data) }),
      }
    {
      "jsonrpc": String("2.0"),
      "id": Number(id),
      "error": { "code": Number(code), "message": String(message), .. },
      ..
    } =>
      {
        id: Number(id.to_int64()),
        result: Err({ code: code.to_int(), message, data: None }),
      }
    {
      "jsonrpc": String("2.0"),
      "id": String(id),
      "error": {
        "code": Number(code),
        "message": String(message),
        "data": data,
        ..
      },
      ..
    } =>
      {
        id: String(id),
        result: Err({ code: code.to_int(), message, data: Some(data) }),
      }
    {
      "jsonrpc": String("2.0"),
      "id": String(id),
      "error": { "code": Number(code), "message": String(message), .. },
      ..
    } =>
      {
        id: String(id),
        result: Err({ code: code.to_int(), message, data: None }),
      }
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected jsonrpc, id, and result or error"),
      )
  }
}

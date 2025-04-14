///|
/// A Request is a message sent to a peer to request behavior.
/// If it has an ID then it is a call and therefore requests a response,
/// otherwise it is a notification which receives no response.
pub(all) struct Request {
  // id of this request, used to tie the Response back to the request.
  // This will be None for notifications.
  id : ID?
  // method_ is a String containing the method name to invoke.
  method_ : String
  // params is either a struct or an array with the parameters of the method.
  params : Json
} derive(Show, Eq)

///|
pub impl ToJson for Request with to_json(self) {
  let obj = {
    "jsonrpc": "2.0".to_json(),
    "method": self.method_.to_json(),
    "params": self.params,
  }
  match self.id {
    Some(String(s)) => obj["id"] = s.to_json()
    Some(Number(n)) => obj["id"] = Number(n.to_double())
    None => ()
  }
  obj.to_json()
}

///|
pub impl @json.FromJson for Request with from_json(json, path) {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object"))
  }
  match obj {
    {
      "jsonrpc": String("2.0"),
      "id": Number(id),
      "method": String(method_),
      "params": params,
      ..
    } => { id: Some(Number(id.to_int64())), method_, params }
    {
      "jsonrpc": String("2.0"),
      "id": String(id),
      "method": String(method_),
      "params": params,
      ..
    } => { id: Some(String(id)), method_, params }
    {
      "jsonrpc": String("2.0"),
      "method": String(method_),
      "params": params,
      ..
    } => { id: None, method_, params }
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected jsonrpc, id, method and params"),
      )
  }
}

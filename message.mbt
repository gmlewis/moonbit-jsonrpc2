///| Message covers all jsonrpc2 message types.
/// They share no common functionality, but are a closed set of concrete types
/// that are allowed to implement this interface. The message types are Request
/// and Response.
pub enum Message {
  // Request is a jsonrpc2 request message.
  Request(Request)
  // Response is a jsonrpc2 response message.
  Response(Response)
} derive(Show, Eq)

///|
pub impl ToJson for Message with to_json(self) {
  match self {
    Request(req) => req.to_json()
    Response(res) => res.to_json()
  }
}

///|
pub impl @json.FromJson for Message with from_json(json, path) {
  let req : Result[Request, @json.JsonDecodeError] = @json.from_json?(json)
  if req is Ok(req) {
    return Request(req)
  }
  let res : Result[Response, @json.JsonDecodeError] = @json.from_json?(json)
  if res is Ok(res) {
    return Response(res)
  }
  raise @json.JsonDecodeError((path, "expected request or response"))
}

///| new_notification constructs a new notification message for the supplied
/// method and parameters.
pub fn new_notification(method_ : String, params : Json) -> Message {
  Request({ id: None, method_, params })
}

///| new_call constructs a new call message for the supplied ID, method and
/// parameters.
pub fn new_call(id : ID, method_ : String, params : Json) -> Message {
  Request({ id: Some(id), method_, params })
}

///|
pub fn is_call(self : Message) -> Bool {
  guard self is Request(req) else { return false }
  req.id is Some(_)
}

///|
pub fn is_notification(self : Message) -> Bool {
  guard self is Request(req) else { return false }
  req.id is None
}

///| new_response constructs a new Response message that is a reply to the
/// supplied. If err is set result may be ignored.
pub fn new_response(id : ID, result : Result[Json, WireError]) -> Message {
  Response({ id, result })
}

///|
pub fn is_response(self : Message) -> Bool {
  self is Response(_)
}

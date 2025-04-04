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
  match @json.from_json!(json) {
    Request(req) => Request(req)
    Response(res) => Response(res)
    _ => raise @json.JsonDecodeError((path, "expected request or response"))
  }
}

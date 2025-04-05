///| Message covers all jsonrpc2 message types.
/// They share no common functionality, but are a closed set of concrete types
/// that are allowed to implement this interface. The message types are Request
/// and Response.
pub enum Message {
  // Request is a jsonrpc2 request message.
  Request(Request)
  // Response is a jsonrpc2 response message.
  Response(Response)
  // BatchRequest is an array of requests.
  BatchRequest(Array[Request])
  // BatchResponse is an array of responses.
  BatchResponse(Array[Response])
} derive(Show, Eq)

///|
pub impl ToJson for Message with to_json(self) {
  match self {
    Request(req) => req.to_json()
    Response(res) => res.to_json()
    BatchRequest(arr_req) => arr_req.to_json()
    BatchResponse(arr_res) => arr_res.to_json()
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
  let arr_req : Result[Array[Request], @json.JsonDecodeError] = @json.from_json?(
    json,
  )
  if arr_req is Ok(arr_req) {
    return BatchRequest(arr_req)
  }
  let arr_res : Result[Array[Response], @json.JsonDecodeError] = @json.from_json?(
    json,
  )
  if arr_res is Ok(arr_res) {
    return BatchResponse(arr_res)
  }
  raise @json.JsonDecodeError((path, "expected request(s) or response(s)"))
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

///| new_response constructs a new Response message.
pub fn new_response(id : ID, result : Result[Json, WireError]) -> Message {
  Response({ id, result })
}

///| new_batch_request constructs a new batch request message for the supplied
/// requests.
pub fn new_batch_request(messages : Array[Message]) -> Message {
  let requests = messages.filter_map(as_request)
  BatchRequest(requests)
}

///| new_batch_response constructs a new batch response message for the supplied
/// responses.
pub fn new_batch_response(messages : Array[Message]) -> Message {
  let responses = messages.filter_map(as_response)
  BatchResponse(responses)
}

///|
pub fn as_call(self : Message) -> Request? {
  guard self is Request(req) else { return None }
  guard req.id is Some(_) else { return None }
  Some(req)
}

///|
pub fn as_notification(self : Message) -> Request? {
  guard self is Request(req) else { return None }
  guard req.id is None else { return None }
  Some(req)
}

///|
pub fn as_request(self : Message) -> Request? {
  if self is Request(req) {
    Some(req)
  } else {
    None
  }
}

///|
pub fn as_response(self : Message) -> Response? {
  if self is Response(res) {
    Some(res)
  } else {
    None
  }
}

///| as_batch_request returns the message as a batch request if it is one.
pub fn as_batch_request(self : Message) -> Array[Request]? {
  if self is BatchRequest(arr_req) {
    Some(arr_req)
  } else {
    None
  }
}

///| as_batch_response returns the message as a batch response if it is one.
pub fn as_batch_response(self : Message) -> Array[Response]? {
  if self is BatchResponse(arr_res) {
    Some(arr_res)
  } else {
    None
  }
}

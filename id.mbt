///|
/// ID is used to identify the request and tie it to the response.
pub enum ID {
  // ID is a number, used to identify the request.
  Number(Int64)
  // ID is a string, used to identify the request.
  String(String)
} derive(Show, Eq)

///|
pub fn ID::number(n : Int64) -> ID {
  Number(n)
}

///|
pub fn ID::string(s : String) -> ID {
  String(s)
}

///|
pub impl ToJson for ID with to_json(self) {
  match self {
    Number(n) => n.to_double().to_json()
    String(s) => s.to_json()
  }
}

///|
pub impl @json.FromJson for ID with from_json(json, path) {
  let n : Result[Double, @json.JsonDecodeError] = @json.from_json?(json)
  if n is Ok(n) {
    return Number(n.to_int64())
  }
  let s : Result[String, @json.JsonDecodeError] = @json.from_json?(json)
  if s is Ok(s) {
    return String(s)
  }
  raise @json.JsonDecodeError((path, "expected number or string"))
}

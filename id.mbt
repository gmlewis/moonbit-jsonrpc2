///|
/// ID is used to identify the request and tie it to the response.
pub enum ID {
  // ID is a number, used to identify the request.
  Number(Int64)
  // ID is a string, used to identify the request.
  String(String)
} derive(Debug, Eq)

///|
pub impl Show for ID with fn output(self, logger) {
  match self {
    Number(n) =>
      logger.write_string(
        (
          $|Number(\{n})
        ),
      )
    String(s) =>
      logger.write_string(
        (
          $|String(\{s.escape(quote=true)})
        ),
      )
  }
}

///|
test "ID show interface" {
  let id1 = ID::number(42)
  inspect(
    id1,
    content=(
      #|Number(42)
    ),
  )
  let id2 = ID::string("foo")
  inspect(
    id2,
    content=(
      #|String("foo")
    ),
  )
}

///|
pub fn ID::number(n : Int64) -> ID {
  Number(n)
}

///|
pub fn ID::string(s : String) -> ID {
  String(s)
}

///|
pub impl ToJson for ID with fn to_json(self) {
  match self {
    Number(n) => n.to_double().to_json()
    String(s) => s.to_json()
  }
}

///|
pub impl @json.FromJson for ID with fn from_json(json, path) {
  try {
    let n : Double = @json.from_json(json, path~)
    return Number(n.to_int64())
  } catch {
    _ => ()
  }
  try {
    let s : String = @json.from_json(json, path~)
    return String(s)
  } catch {
    _ => ()
  }
  raise @json.JsonDecodeError((path, "expected number or string"))
}

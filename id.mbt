///| ID is used to identify the request and tie it to the response.
pub enum ID {
  // ID is a number, used to identify the request.
  Number(Int64)
  // ID is a string, used to identify the request.
  String(String)
} derive(Show, Eq)

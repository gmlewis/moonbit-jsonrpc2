///|
test "@jsonrpc2.ID/json-encoding" {
  let id1 = @jsonrpc2.ID::number(42)
  let id2 = @jsonrpc2.ID::string("request-1")

  // Test JSON encoding
  inspect!(id1.to_json(), content="Number(42)")
  inspect!(
    id2.to_json(),
    content=
      #|String("request-1")
    ,
  )

  // Test JSON decoding
  let json1 = @json.parse!("42")
  let json2 = @json.parse!("\"request-1\"")
  let decoded1 : @jsonrpc2.ID = @json.from_json!(json1)
  let decoded2 : @jsonrpc2.ID = @json.from_json!(json2)
  inspect!(decoded1, content="Number(42)")
  inspect!(decoded2, content="String(\"request-1\")")
}

///|
test "@jsonrpc2.ID/equality" {
  let id2 = @jsonrpc2.ID::number(42)
  let id3 = @jsonrpc2.ID::number(42)
  let id4 = @jsonrpc2.ID::string("42")
  let id5 = @jsonrpc2.ID::string("42")
  let id6 = @jsonrpc2.ID::number(43)

  // Same type, same value should be equal
  assert_eq!(id2, id3)
  assert_eq!(id4, id5)

  // Different type or value should not be equal
  assert_not_eq!(id2, id4)
  assert_not_eq!(id2, id6)
}

///|
test "@jsonrpc2.ID/edge-cases" {
  // Test with maximum Int64 value - note loss of precision
  let max_id = @jsonrpc2.ID::number(9223372036854775807)
  inspect!(max_id.to_json(), content="Number(9223372036854776000)")

  // Test with empty string
  let empty_id = @jsonrpc2.ID::string("")
  inspect!(
    empty_id.to_json(),
    content=
      #|String("")
    ,
  )

  // Test decoding from JSON
  let json1 = @json.parse!("9223372036854775807")
  let json2 = @json.parse!("\"\"")
  let decoded1 : @jsonrpc2.ID = @json.from_json!(json1)
  let decoded2 : @jsonrpc2.ID = @json.from_json!(json2)
  inspect!(decoded1, content="Number(0)")
  inspect!(decoded2, content="String(\"\")")
}

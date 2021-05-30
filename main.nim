import db_sqlite, json, asynchttpserver, asyncdispatch, re, strutils

var db = open("main.db", "", "", "")
var config: JsonNode = parseFile("config.json")

let server = newAsyncHttpServer()

type
  Qarr = object
    column: string
    queryvar: JsonNode
    condition: string
    querytype: string
  QueryRequest = object
    table: string
    fields: seq[string]
    queryarr: seq[Qarr]
    limit: int

proc queryHandler(req: Request) {.async.} =
  # parse json
  var jn: JsonNode
  try:
    jn = parseJson(req.body)
  except:
    await req.respond(Http400, "Invalid Json")
    return

  var obj: QueryRequest
  try:
    obj = to(jn, QueryRequest)
  except JsonKindError:
    await req.respond(Http400, "Invalid Type in Json")
    return

  # validate json
  if (not match(obj.table, re"^[A-Za-z]+$")) or obj.limit < 1 or obj.limit > 30:
    await req.respond(Http400, "Invalid Data")
    return

  var currentTable: JsonNode
  var found = false
  # get table out of validation config
  for table in config["tables"].getElems():
    if table["name"].getStr() == obj.table:
      found = true
      currentTable = table
  if not found:
    await req.respond(Http400, "Table doesn't exist")
    return

  for el in obj.fields:
    if not match(el, re"^[A-Za-z]+$"):
      await req.respond(Http400, "Invalid Fielddata")
      return

  for el in obj.queryarr:
    var foundColumn = false
    if not match(el.column, re"^[A-Za-z]+$") or not (el.condition in ["WHERE",
        "OR", "AND"]) or not (el.querytype in ["=", "<", ">", "<=", ">=", "<>", "NOT"]):
      await req.respond(Http400, "Invalid Query")
      return
    for col in currentTable["columns"].getElems():
      if col["name"].getStr() == el.column and col["accessible"].getBool():
        foundColumn = true
    if not foundColumn:
      await req.respond(Http400, "Column doesn't exist or isn't accessible.")
      return

  # create sql query
  var
    fieldsStr: string
    queryStr: string
  let fieldsLen: int = len(obj.fields) - 1
  for i, field in obj.fields:
    fieldsStr &= field
    if i < fieldsLen:
      fieldsStr &= ","

  queryStr = "SELECT " & fieldsStr & " FROM " & obj.table & " "

  for i, query in obj.queryarr:
    queryStr &= query.condition & " "
    queryStr &= query.column & " "
    queryStr &= query.querytype & " "
    for column in currentTable["columns"].getElems():
      if column["name"].getStr() == query.column:
        let v = column["validation"]
        if v["type"].getStr() == "string":
          let l = len(query.queryvar.getStr())
          echo l
          if l > v["maxLen"].getInt() or l < v["minLen"].getInt():
            await req.respond(Http400, "Invalid length of query string")
            return
        elif v["type"].getStr() == "number":
          if query.queryvar.getInt() < v["min"].getInt() or
              query.queryvar.getInt() > v["max"].getInt():
            await req.respond(Http400, "Invalid size of query number")
            return

    queryStr &= $(query.queryvar) & " " # TODO: Check datatype of queryvar

  echo queryStr
  # execute query
  try:
    var jnstr = $( %* db.getAllRows(sql(queryStr)))
    let headers = newHttpHeaders([("Content-Type", "application/json")])
    await req.respond(Http200, jnstr, headers)
    return
  except:
    await req.respond(Http400, "DB Error")

proc handler(req: Request) {.async, gcsafe.} =
  if req.reqMethod == HttpGet:
    if req.url.path == "/":
      await req.respond(Http200, "Hallo");
    elif req.url.path == "/query":
      await queryHandler(req)
    else:
      await req.respond(Http404, "Not Found")
  else:
    await req.respond(Http400, "Bad Request")

waitFor server.serve(Port(8000), handler)

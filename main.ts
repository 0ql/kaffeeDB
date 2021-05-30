function isAlpha(str: string): boolean {
  return /^[a-zA-Z]+$/.test(str)
}

function isSupportedType(type: string): boolean {
  return ["null", "int", "float", "bool", "string"].includes(type)
}

type queryRequest = {
  table: string | null
  fields: string[],
  queryarr: {
    column: string
    queryvar: number | string
    condition: "WHERE" | "NOT" | "OR"
    querytype: "<" | ">" | "<>" | "=" | "<=" | ">=" | "NOT"
  }[]
  limit: number | null
}

export class Query {
  private req: queryRequest
  private baseURL: string

  constructor(baseURL: string) {
    this.baseURL = baseURL ?? ""
    this.req = {
      table: null,
      fields: [],
      queryarr: [],
      limit: null
    }
  }

  public table(table: string): this {
    this.req.table = table
    return this
  }

  public fields(fields: string[]): this {
    this.req.fields = fields
    return this
  }

  public where(column: string, compare: "<" | ">" | "<" | ">" | "<>" | "=" | "<=" | ">=", val: number | string): this {
    this.req.queryarr.push({
      column: column,
      queryvar: val,
      condition: "WHERE",
      querytype: compare
    })
    return this
  }

  public not(column: string, compare: "<" | ">" | "<" | ">" | "<>" | "=" | "<=" | ">=", val: number | string): this {
    this.req.queryarr.push({
      column: column,
      queryvar: val,
      condition: "NOT",
      querytype: compare
    })
    return this
  }

  public or(column: string, compare: "<" | ">" | "<" | ">" | "<>" | "=" | "<=" | ">=", val: number | string): this {
    this.req.queryarr.push({
      column: column,
      queryvar: val,
      condition: "OR",
      querytype: compare
    })
    return this
  }

  public limit(amount: number): this {
    this.req.limit = amount
    return this
  }

  public async send(callback: (jn: Record<string, unknown>) => void) {
    console.log(this.req)
    const res = await fetch(`${this.baseURL}/query`, {
      method: "POST",
      credentials: "include",
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(this.req)
    })

    if (res.status === 200) {
      const jn = await res.json()
      callback(jn)
    } else {
      throw new Error(res.status.toString())
    }
  }
}

type createRequest = {
  table: string | null
  row: Record<string, unknown>
}


export class Create {
  private baseURL: string
  private req: createRequest
  constructor(baseURL: string) {
    this.baseURL = baseURL
    this.req = {
      table: "",
      row: {}
    }
  }

  public table(table: string): this {
    this.req.table = table
    return this
  }

  public row(row: Record<string, unknown>): this {
    this.req.row = row
    return this
  }

  public async send(callback: (jn: Response) => void) {
    console.log(this.req)
    const res = await fetch(`${this.baseURL}/create`, {
      method: "POST",
      credentials: "include",
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(this.req)
    })

    if (res.status === 200) {
      callback(res)
    } else {
      throw new Error(res.status.toString())
    }
  }
}

type supported = "null" | "int" | "float" | "bool" | "string"

type config = {
  min?: number; // min length of string of size of number
  max?: number; // max length of string or size of number
  len?: number; // exact length of string
} // TODO add all k
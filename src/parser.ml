open Ast

type parser_t =
  { tokens : Token.token_t list }

let parser_create tokens : parser_t =
  { tokens }

let expect p expected_type : parser_t * Token.token_t =
  match p.tokens with
  | [] -> failwith "no more tokens"
  | hd :: tl when hd.tokentype = expected_type -> { tokens = tl }, hd
  | hd :: _ ->
     let _ = Err.err ("expected token " ^ (Token.tokentype_tostr expected_type) ^ " but got " ^ hd.data) in 
     failwith "expected token"


let eat p : parser_t * Token.token_t =
  match p.tokens with
  | [] ->
     let _ = Err.err "no tokens error" in
     failwith "parser error"
  | hd :: tl -> { tokens = tl }, hd


let at p : Token.token_t =
  match p.tokens with
  | [] ->
     let _ = Err.err "no tokens error" in
     failwith "parser error"
  | hd :: _ -> hd


let rec parse_primary_expr p : parser_t * node_expr_t =
  match at p with
  | t when t.tokentype = Token.ID ->
     let p, t = eat p in
     p, NodeTerm (NodeTermID { id = t })
  | t when t.tokentype = Token.IntegerLiteral ->
     let p, t = eat p in
     p, NodeTerm (NodeTermIntLit { intlit = t })
  | t when t.tokentype = Token.LParen ->
     let p, _ = eat p in
     let p, expr = parse_expr p in
     let p, _ = expect p Token.RParen in
     p, expr
  | _ ->
     let _ = Err.err ("could not parse primary expression. unexpected token " ^ (at p).data) in 
     failwith "unexpected token"


and parse_multiplicitave_expr p : parser_t * node_expr_t =
  let p, lhs = parse_primary_expr p in
  let rec parse_multiplicitave_expr (p : parser_t) (lhs : node_expr_t) : parser_t * node_expr_t =
    match at p with
    | t when t.tokentype = Token.Asterisk || t.tokentype = Token.ForwardSlash->
       let p, t = eat p in
       let p, rhs = parse_primary_expr p in
       parse_multiplicitave_expr p (NodeBinExpr { lhs = lhs; rhs = rhs; op = t.data })
    | _ -> p, lhs in
  parse_multiplicitave_expr p lhs


and parse_additive_expr p : parser_t * node_expr_t =
  let p, lhs = parse_multiplicitave_expr p in
  let rec parse_additive_expr (p : parser_t) (lhs : node_expr_t) : parser_t * node_expr_t =
    match at p with
    | t when t.tokentype = Token.Plus || t.tokentype = Token.Hyphen->
       let p, t = eat p in
       let p, rhs = parse_multiplicitave_expr p in
       parse_additive_expr p (NodeBinExpr { lhs = lhs; rhs = rhs; op = t.data })
    | _ -> p, lhs in
  parse_additive_expr p lhs


and parse_expr p : parser_t * node_expr_t =
  let p, expr = parse_additive_expr p in
  p, expr


let parse_stmt p : parser_t * node_stmt_t =
  match at p with
  | t when t.tokentype = Token.Exit ->
     let p, _ = eat p in
     let p, expr = parse_expr p in
     let p, _ = expect p Token.SemiColon in
     p, NodeStmtExit { expr }
  | t when t.tokentype = Token.Let ->
     let p, _ = eat p in
     let p, id = expect p Token.ID in
     let p, _ = expect p Token.Equals in
     let p, expr = parse_expr p in
     let p, _ = expect p Token.SemiColon in
     p, NodeStmtLet { id; expr }
  | t when t.tokentype = Token.Println ->
     let p, _ = eat p in
     let p, expr = parse_expr p in
     let p, _ = expect p Token.SemiColon in
     p, NodeStmtPrintln { expr }
  | _ ->
     let _ = Err.err ("unexpected token " ^ (at p).data) in
     failwith "parser error"


(* Entrypoint. *)
let parse_program tokens : node_prog_t =
  let p = { tokens } in
  let rec produce_program p program : node_prog_t =
    match p.tokens with
    | [] -> program
    | hd :: _ when hd.tokentype = Token.EOF -> program
    | _ -> 
       let p, stmt = parse_stmt p in
       produce_program p { stmts = program.stmts @ [stmt] }
  in
  produce_program p { stmts = [] }

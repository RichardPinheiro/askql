{
  const path = require('path');
  const ask = require(path.join(
    __dirname,
    process.env.NODE_ENV === 'test'
      ? '../../../../src'
      : '../../../dist',
    'askscript/parser/askscript.grammar.pegjs.classes'
  ));
}


// === ask { ===

ask = lineWithoutCode* aH:askHeader aB:askBody askFooter lineWithoutCode* eof {
  return new ask.Ask(aH, aB);
}

askForRepl = lineWithoutCode* ws* 'ask' aL:askHeader_argList? aRT:askHeader_retType? ws* '{' .*

askHeader = ws* 'ask' aL:askHeader_argList? aRT:askHeader_retType? ws* '{' ws* lineComment? {
  return new ask.AskHeader(aL === null ? [] : aL, aRT);
}
askHeader_argList = ws* '(' aL:argList ')' { return aL }
askHeader_retType = ws* ':' ws* t:type { return t }

askFooter = blockFooter ws*

askBody = sL:statementList { return new ask.AskBody(sL) }


// === statements ===

statementList = lineWithoutCode* sL:statementList_NoEmptyLines lineWithoutCode* { return sL }
statementList_NoEmptyLines = 
      s:statement ws* lineComment? lineWithoutCode* sL:statementList { return sL.unshift(s), sL }
    / s:statement ws* lineComment? {                                      return [s] }
    / '' {                                                                return [] }

// statement is at least one full line
// statement does NOT include the trailing newline
statement = ws* s:statement_NoWs ws* { return s }
statement_NoWs = 
    s:(
      functionDefinition
      / variableDefinition
      / if
      / while
      / forOf
      / forIn
      / for3
      / return
      / assignment
      / value
    ) { return new ask.Statement(s) }


// === variables ===

// variables other than of function type
variableDefinition = 
      vD:variableDeclaration ws* '=' ws* v:value { return new ask.VariableDefinition(vD, v) }
    / vD:variableDeclaration {                     return new ask.VariableDefinition(vD) }
variableDeclaration = 
      m:modifier ws+ i:(identifier/operator) t:variableDefinition_type? { return new ask.VariableDeclaration(m, i, t === null ? ask.anyType : t) }
variableDefinition_type = ws* ':' ws* t:type { return t }


// === value ===

value = 
    e:(
      functionObject
    / remote
    / functionCall
    / query
    / valueLiteral
    / identifier)
    mCAs:methodCallApplied* { return new ask.Value(e, mCAs) }


// === function definition ===

functionDefinition = fS:functionSignature ws* '=' ws* fO:functionObject {                             return new ask.FunctionDefinition(fS, fO) }

functionObject = fH:functionHeader cB:codeBlock functionFooter {                                      return new ask.FunctionObject(fH, cB) }

functionSignature = m:modifier ws+ i:identifier tD:functionHeader_typeDecl? {                         return new ask.FunctionSignature(m, i, tD) }
functionHeader = 'fun' ws* '(' aL:argList ')' rTD:functionHeader_returnTypeDecl? ws* '{' ws* lineComment? {  return new ask.FunctionHeader(aL, rTD === null ? ask.anyType : rTD) }
functionHeader_typeDecl = ws* ':' ws* t1:functionType { return t1 } // this is the optional variable type declaration
functionHeader_returnTypeDecl = ws* ':' ws* t2:type { return t2 } // this is the optional return type declaration

functionFooter = blockFooter


// === code block ===

codeBlockWithBraces = '{' ws* cB:codeBlock nlws* '}' { return cB; }

codeBlock = statementList


// === query ===

query = queryHeader qFL:queryFieldList queryFooter { return new ask.Query(qFL) }

queryHeader = 'query {' ws* lineComment?
queryFieldList = 
    lineWithoutCode* qF:queryField ws* lineComment? lineWithoutCode* qFL:queryFieldList {  return qFL.unshift(qF), qFL }
  / lineWithoutCode* qF:queryField ws* lineComment? lineWithoutCode* {                     return [qF] }
  / lineWithoutCode* {                                                                        return [] }

queryField = 
    ws* i:identifier ws* ':' ws* v:value qFL:queryFieldBlock? {                  return new ask.QueryField(i, v, qFL) }

    // This is double quote in fact (the second ':' is leading the methodCallApplied rule)
  / ws* i:identifier ws* ':' ws* mCAs:methodCallApplied* qFL:queryFieldBlock? {  return new ask.QueryField(i, new ask.Value(i, mCAs), qFL) }
  / ws* i:identifier qFL:queryFieldBlock? {                                      return new ask.QueryField(i, new ask.Value(i, []), qFL) }

queryFieldBlock = ws* '{' ws* lineComment? lineWithoutCode* qFL:queryFieldList ws* '}' { return qFL }

queryFooter = blockFooter


// === remote ===

remote = rH:remoteHeader cB:codeBlockWithBraces {    return new ask.Remote(rH, cB) }

remoteHeader = 
    'remote(' ws* url:value ws* ',' ws* args:map ws* ')' ws* { return new ask.RemoteHeader(url, args) }
  / 'remote(' ws* url:value ws* ')' ws* {                      return new ask.RemoteHeader(url, new ask.Map([])) }

// === lists: arg list, call list, value list ===

argList = // TODO: check all the *List constructs for handling empty lists
    aL:nonEmptyArgList { return aL }
  / '' {                 return [] }

nonEmptyArgList =
    a:arg ',' aL:argList { return aL.unshift(a), aL }
  / a:arg { return [a] }

arg = ws* i:identifier ws* t:argType? { return new ask.Arg(i, t === null ? ask.anyType : t) }
argType = ':' ws* t:type ws* { return t }

callArgList = v:valueList { return v }
valueList = 
    vL:nonEmptyValueList { return vL}
  / ws* { return [] }

nonEmptyValueList = 
    ws* v:value ws* ',' vL:nonEmptyValueList { vL.unshift(v); return vL }
  / ws* v:value ws* { return [v] }


// === control flow ===

if     = 'if' ws* '(' v:value ')' ws* cB:codeBlockWithBraces ws* eB:elseBlock? { return new ask.If(v, cB, eB) }
while  = 'while' ws* '(' v:value ')' ws* cB:codeBlockWithBraces {                return new ask.While(v, cB) }
forOf  = 'for'   ws* '(' vD:variableDeclaration ws+ 'of' ws+ v:value ws* ')' ws* cB:codeBlockWithBraces { return new ask.ForOf(vD, v, cB)}
forIn  = 'for'   ws* '(' vD:variableDeclaration ws+ 'in' ws+ v:value ws* ')' ws* cB:codeBlockWithBraces { return new ask.ForIn(vD, v, cB)}
for3   = 'for'   ws* '(' ws* s1:statement_NoWs? ws* ';' ws* s2:statement_NoWs ws* ';' ws* s3:statement_NoWs ws* ')' ws* cB:codeBlockWithBraces { return new ask.For3(s1, s2, s3, cB)}
elseBlock = 'else' ws* cB:codeBlockWithBraces { return new ask.Else(cB) }
return = 
    'return' wsnonl+ v:value {  return new ask.Return(v) }
  / 'return' wsnonl* {          return new ask.Return(ask.nullValue) }

// ===     ====

assignment = i:identifier ws* '=' ws* v:value { return new ask.Assignment(i, v) }


// === function and method calls ===

functionCall = i:identifier ws* '(' cAL:callArgList ')' {                       return new ask.FunctionCall(i, cAL) }
methodCallApplied   = 
    ws* ':' ws* iop:(identifier/operator) ws* cAL:methodCallAppliedArgList?  { return new ask.MethodCallApplied(iop, cAL === null ? [] : cAL)}
methodCallAppliedArgList = '(' cAL:callArgList ')' { return cAL }


// === simple elements ===

functionType = 
  type ws* '(' ws* typeList ws* ')'
  / type
typeList = 
    tL:nonEmptyTypeList { return tL }
  / '' {                  return [] }
nonEmptyTypeList = 
    ws* t:type ws* ',' tL:nonEmptyTypeList { return tL.unshift(t), tL }
  / ws* t:type { return [t] }

type = 
    'array(' t:type ')'  {  return new ask.ArrayType(t) }
  / 'map(' t:type ')' {     return new ask.MapType(t) }
  / i:identifier {          return new ask.Type(i) }


valueLiteral = 
    v:(
      null
      / boolean
      / float // float needs to go before int
      / int
      / string
      / array
      / map
    ) { return new ask.ValueLiteral(v) }

string = "'" sC:stringContents  "'" { return sC }
stringContents = ch* { return new ask.String(text()) }

array = '[' vL:valueList ']' { return new ask.Array(vL) }
map = '{' mEL:mapEntryList '}' { return new ask.Map(mEL) }

mapEntryList = 
    ws* mE:mapEntry ws* ',' mEL:mapEntryList {  return mEL.unshift(mE), mEL }
  / ws* mE:mapEntry ws* {                       return [mE] }
  / ws* {                                       return [] }

mapEntry = 
    i:identifier ws* ':' ws* v:value {                 return new ask.MapEntry(i, v) }

  // This is double quote in fact (the second ':' is leading the methodCallApplied rule)
  / i:identifier ws* ':' ws* mCAs:methodCallApplied* { return new ask.MapEntry(i, new ask.Value(i, mCAs)) }
  / ws* i:identifier {                                 return new ask.MapEntry(i, new ask.Value(i, [])) }


modifier = const / let
const = 'const' { return new ask.Const() }
let = 'let' { return new ask.Let() }

blockFooter = ws* '}'

lineWithoutCode = 
    lineWithComment
  / emptyLine

lineWithComment = lineComment

lineComment = ws* '//' (!nl .)* (nl / eof)

emptyLine = ws* nl
nlws = nl / ws

// === literals ===
identifier = [_$a-zA-Z][-_$a-zA-Z0-9]* { return new ask.Identifier(text()) } // TODO: add Unicode here
operator   = [-<>+*/^%=]+ {              return new ask.Identifier(text()) }
null = 'null' { return new ask.Null() }
boolean = true / false
true = 'true' { return new ask.True() }
false = 'false' { return new ask.False() }
int = [-]?[0-9]+ { return new ask.Int(text()) }               // TODO: yes, multiple leading zeros possible, I might fix one day
float = [-]?[0-9]+ '.' [0-9]+ { return new ask.Float(text()) }  // TODO: yes, multiple leading zeros possible, I might fix one day

// === character classes ===

// character (in string)
ch = 
  '\\' escape
  / [\x20-\x26\x28-\x5B\x5D-\xff] // all printable characters except ' (\x27) and \ (\x5C)

escape =
      "'"
    / '\\'  // this is one backslash
    / 'u' hex hex hex hex

// digits (dec and hex)
hex = [0-9A-Fa-f]

digit = [0-9]
onenine = [1-9]


// whitespace
ws = wsnonl / nl
wsnonl = ' ' / '\t'

// new line
nl = '\n' / '\r'


// end of file
eof = (!.)


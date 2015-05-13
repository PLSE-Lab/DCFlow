@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::\syntax::DCFlowSyntax

lexical Comment
	= @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
	| @category="Comment" "//" ![\n]* !>> [\ \t\r \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000] $ // the restriction helps with parsing speed
	;

lexical LAYOUT
	= Comment 
	// all the white space chars defined in Unicode 6.0 
	| [\u0009-\u000D \u0020 \u0085 \u00A0 \u1680 \u180E \u2000-\u200A \u2028 \u2029 \u202F \u205F \u3000] 
	;

layout LAYOUTLIST
	= LAYOUT* !>> [\u0009-\u000D \u0020 \u0085 \u00A0 \u1680 \u180E \u2000-\u200A \u2028 \u2029 \u202F \u205F \u3000] !>> "//" !>> "/*";

lexical CName
    // Names are surrounded by non-alphabetical characters, i.e. we want longest match.
	=  ([A-Z a-z _] !<< [A-Z _ a-z] [0-9 A-Z _ a-z]* !>> [0-9 A-Z _ a-z]) \ CFGKeywords 
	| [\\] [A-Z _ a-z] [\- 0-9 A-Z _ a-z]* !>> [\- 0-9 A-Z _ a-z] 
	;

keyword RascalKeywords
	= "o"
	| "syntax"
	| "keyword"
	| "lexical"
	| "int"
	| "break"
	| "continue"
	| "rat" 
	| "true" 
	| "bag" 
	| "num" 
	| "node" 
	| "finally" 
	| "private" 
	| "real" 
	| "list" 
	| "fail" 
	| "filter" 
	| "if" 
	| "tag" 
	| \value: "value" 
	| \loc: "loc" 
	| \node: "node" 
	| \num: "num" 
	| \type: "type" 
	| \bag: "bag" 
	| \int: "int"
	| rational: "rat" 
	| relation: "rel" 
	| listRelation: "lrel"
	| \real: "real" 
	| \tuple: "tuple" 
	| string: "str" 
	| \bool: "bool" 
	| \void: "void" 
	| dateTime: "datetime" 
	| \set: "set" 
	| \map: "map" 
	| \list: "list" 
	| "extend" 
	| "append" 
	| "rel" 
	| "lrel"
	| "void" 
	| "non-assoc" 
	| "assoc" 
	| "test" 
	| "anno" 
	| "layout" 
	| "data" 
	| "join" 
	| "it" 
	| "bracket" 
	| "in" 
	| "import" 
	| "false" 
	| "all" 
	| "dynamic" 
	| "solve" 
	| "type" 
	| "try" 
	| "catch" 
	| "notin" 
	| "else" 
	| "insert" 
	| "switch" 
	| "return" 
	| "case" 
	| "while" 
	| "str" 
	| "throws" 
	| "visit" 
	| "tuple" 
	| "for" 
	| "assert" 
	| "loc" 
	| "default" 
	| "map" 
	| "alias" 
	| "any" 
	| "module" 
	| "mod"
	| "bool" 
	| "public" 
	| "one" 
	| "throw" 
	| "set" 
	| "start"
	| "datetime" 
	| "value" 
	;
	
keyword CFGKeywords
	= RascalKeywords
	| "rule"
	| "entry"
	| "exit"
	| "self"
	| "header"
	| "footer"
	| "jumpToExit"
	| "ignore"
	| "edge"
	| "label"
	| "unstructured"
	| "structured"
	| "target"
	| "ast"
	| "context"
	| "astType"
	| "create"
	| "jump"
	| "nothing"
	| "first"
	| "last"
	| "next"
	| "following"
	| "is"
	;
	
syntax CQualifiedName
	= \default: {CName "::"}+ names !>> "::"
	;

syntax CQualifiedNameWithArity
	= \default: CQualifiedName name
	| withIndex: CQualifiedName name "/" NaturalNumber arity
	| withFields : CQualifiedName name "{" {CName ","}+ names "}"
	;
	
start syntax CModule 
	= \default: "module" CQualifiedName name CImport* imports CRule* rules;
	
syntax CImport
	= \default: "import" CQualifiedName name ";"
	| astImport: "ast" CQualifiedName name ";"
	;

syntax CRule
	= \default: "rule" CQualifiedNameWithArity+ target "=" {CRulePart ","}+ parts ";"
	| context: "context" CQualifiedNameWithArity+ target ";"
	| asttype: "astType" CQualifiedName name ";"
	| starget: "structured" "target" CQualifiedName+ names ";"
	| utarget: "unstructured" "target" CQualifiedName+ names ";"
	| ignore: "ignore" CQualifiedNameWithArity+ target ";"
	| edgeLabels: "edge" "label" CName+ labelNames ";"
	| nodeLabels: "node" "label" CName+ labelNames ";"
	;
	
syntax CRulePart
	= left link: CRulePart l CArrow a CRulePart r
	| \default: CRuleItem item
	| addNode: "create" "(" CBaseName createName ")"
	| jump: "jump" "(" CRuleItem jumpItem ")"
	| jumpWithType: "jump" "(" CRuleItem jumpItem "," CName targetType ")"
	| jumpWithTarget: "jumpToTarget" "(" CName targetType ")"
	| cond: "if" "(" CPredOp op ")" "{" CRulePart ifPart "}" "else" "{" CRulePart elsePart "}"
	| nothing: "#nothing" 
	| foreach: "for" "(" CName var "\<-" CRuleItem item ")" "{" CRulePart febody "}"
	| entry: "entry" "(" {CRuleItem ","}+ items ")"
	| exit: "exit" "(" {CRuleItem ","}+ items ")"
	| target: "jumpTarget" "(" CRuleItem item ")" 
	| targetWithType: "jumpTarget" "(" CRuleItem item "," CName targetType ")" 
	;

syntax CArrow
	= \default: CDash dashes "\>"
	| labeled:  CDash dashes {CName ","}+ names CDash moreDashes "\>"
	;
	
syntax CPredOp
	= emptyPred: "empty?" "(" CItemName item ")"
	| firstPred: "first?" "(" CItemName item ")"
	| lastPred: "last?" "(" CItemName item ")"
	| is: CItemName item "is" CQualifiedName consName
	;
	
lexical CDash
	= \default: "-" !<< "-"+ !>> "-"
	;
	
syntax CRuleItem
	= \default: CDecorations? decorations CItemName itemName // CWithClause? withParts
	;

lexical NaturalNumber
	= "0" !>> [0-9] 
	| [1-9] [0-9]* !>> [0-9] 
	;

syntax CItemName
	= \default: CBaseName baseName !>> "."
	| \seq: CBaseName baseName "." {CName "."}+ namePath
	;
	
syntax CBaseName
	= \default: CName fieldName
	| self: "self"
	| following: "following"
	| first: "first" !>> "?"
	| last: "last" !>> "?"
	| next: "next" !>> "("	
	| headerNode: "header" !>> "("
	| footerNode: "footer" !>> "("
	| exitNode: "exit" !>> "("
	| entryNode: "entry" !>> "("
	;
	
lexical CDecorations
	= \default: CDecoration !<< CDecoration+ decorationList !>> CDecoration
	;
		
lexical CDecoration
	= markEntryLabel: "^"
	| markExitLabel: "$"
	| markCheckLabel: "?"
	| markLoopTarget: "@"
	| markJumpItem: "!"
	;
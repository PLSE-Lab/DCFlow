@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::ide::Check

import lang::dcflow::\syntax::DCFlowSyntax;
import lang::dcflow::generate::GenerateUtils;
import lang::dcflow::\syntax::SyntaxUtils;
import lang::dcflow::ast::AbstractSyntax;

import ParseTree;
import util::IDE;
import List;
import Set;
import Message;

private CQualifiedName extractQualifiedName((CQualifiedNameWithArity)`<CQualifiedName qn>`) = qn;
private CQualifiedName extractQualifiedName((CQualifiedNameWithArity)`<CQualifiedName qn> / <NaturalNumber _>`) = qn;
private CQualifiedName extractQualifiedName((CQualifiedNameWithArity)`<CQualifiedName qn> { <{CName ","}+ _> }`) = qn;

public set[Message] checkRuleTypesForLoc(loc l) {
	t = checkRuleTypes(parse(#start[CModule],l));
	if ( (t@messages)? ) {
		return t@messages;
	}
	return { };
}

public Tree checkRuleTypes(Tree t) {
	set[Message] messages = { };
	
	astImports = [ "<qn>" | /(CImport)`ast <CQualifiedName qn>;` := t ];
	if (size(astImports) == 0) {
		messages = messages + error("At least one AST module must be imported", t@\loc);
	}
	
	astType = "";
	astTypes = [ "<qn>" | /(CRule)`astType <CQualifiedName qn>;` := t ];
	if (size(astTypes) > 0) {
		astType = astType[0]; 
	} else {
		contexts = [ tn | /(CRule)`context <CQualifiedNameWithArity+ qnl>;` := t, qn <- qnl, < tn, cn, ruleArity > := splitTarget(qn) ];
		if (size(contexts) > 0) {
			astType = contexts[0];
		} else {
			messages = messages + error("No AST type information found", t@\loc);
		}		
	}
	
	if (size(messages) > 0) {
		return t[@messages=messages];
	}
	
	// TODO: We need some way to see if this type is actually
	// available, right now we don't check this in fetchTypeInfo
	// but assume it instead...
	tinfo = fetchTypeInfo(astImports, astType);
	
	// Grab back all the rules so we can see which types are annotated
	allRules = { < tn, cn, ruleArity, r > | /r:(CRule)`rule <CQualifiedNameWithArity+ qnl> = <{CRulePart ","}+ rpl>;` := t, qn <- qnl, < tn, cn, ruleArity > := splitTarget(qn) };
	allIgnores = { < tn, cn, ruleArity, r > | /r:(CRule)`ignore <CQualifiedNameWithArity+ qnl>;` := t, qn <- qnl, < tn, cn, ruleArity > := splitTarget(qn) };
	annotatedTypes = allRules<0> + allIgnores<0>;
	
	// Grab back information on the actual types
	actualTypes = fieldTypes(tinfo);
	
	// Check each given rule
	// TODO: Improve error marker locations, now just marks the entire rule for invalid type or constructor
	for ( < tn, cn, ruleArity, r > <- allRules ) {
		if (tn in actualTypes<0>) {
			if (cn in actualTypes[tn]<0>) {
				try {
					cInfo = getConstructorInfo(actualTypes, tn, cn, ruleArity); 
					fieldsUsed = { < removeStartingSlash("<fn>"), fn@\loc > | /(CBaseName)`<CName fn>` := r};
					for ( < fn, fnloc > <- fieldsUsed, ((fn[0] == "\\") ? fn[1..] : fn) notin cInfo.consTypes<0>) {
						messages = messages + error("Name <fn> is not a valid field name on constructor <cn>", fnloc); 
					}
				} catch errormsg : {
					messages = messages + error("No constructor of the given arity was found", r@\loc);
				}
			} else {
				messages = messages + error("Constructor <cn> is not a valid constructor name", r@\loc);
			}
		} else {
			messages = messages + error("Type <tn> is not a valid type name", r@\loc);
		}
	}
	
	// Look for missing rules
	// TODO: Commented out because of a bug in the annotator, this is causing
	// the markings to be added then quickly removed for some reason...
	//for (< tn, cn > <- ( actualTypes<0,1> - (allRules<0,1> + allIgnores<0,1>) )) {
	//	messages = messages + error("No rule found for type <tn>, constructor <cn>", t@\loc);
	//}
	
	if (size(messages) > 0) {
		return t[@messages = messages];
	}
	
	return t;
}

public Contribution createCheckerContribution() = annotator(checkRuleTypes);
@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::generate::GenerateUtils

import lang::dcflow::ast::AbstractSyntax;
import lang::rascal::types::AbstractType;

import Set;
import List;
import Type;
import IO;
import String;

import util::Eval;

public set[str] getAnnotatedTypes(Program p) = { r.targetType | r <- p.rules };

data ListInfo = linfo(str listVar, str currentVar, str indexVar);

data ConstructorInfo = cinfo(str typeName, str consName, lrel[str fieldName, Symbol fieldType] consTypes);

@doc{The state used by the generator}
data GenState 
	= genState(type[&T] programType, 
			   set[str] annotatedTypeNames,
			   rel[str,str,ConstructorInfo] fieldTypes,
			   rel[Symbol,Symbol] reachableTypes,
			   set[str] structuredTargets,
			   set[str] unstructuredTargets,
			   set[str] generatedFields,
			   map[str,str] varNames,
			   list[ListInfo] listStack,
			   Program p
			  );

public bool isForEachVar(GenState gs, str v) {
	return v in { cv | linfo(_,cv,_) <- gs.listStack };
}

public str getForEachList(GenState gs, str v) {
	for (linfo(listVar,v,_) <- reverse(gs.listStack)) {
		return listVar;
	}
	println("WARNING: No list associated with foreach var <v>");
	return "";
}

private map[str,str] defaultVarNames() 
	= ( "item" : "item", "labels" : "labels", "res" : "res", "ls" : "ls", 
	"validLabels" : "validLabels", "l" : "l", "edges" : "edges", "i" : "i", 
	"exlab" : "exlab", "fn" : "fn", "targetLabel" : "targetLabel", 
	"targetLabels" : "targetLabels");

public GenState resetVarNames(GenState gs) { 
	gs.varNames = defaultVarNames();
	return gs;
}

@doc{Create the generator state, based on the AST type of the language being processed and the set of annotated types.}
public GenState createGenState(Program p) {
	type[&T] pgm = fetchTypeInfo(p.astSources+p.imports,p.astType);
	gs = genState(pgm, getAnnotatedTypes(p), fieldTypes(pgm), reachableTypes(pgm), { }, { }, { }, defaultVarNames(), [], p);
	
	if (isEmpty(p.structuredTargets)) {
		gs.structuredTargets = { ":break", ":continue" };
	} else {
		gs.structuredTargets = p.structuredTargets;
	}

	if (isEmpty(p.unstructuredTargets)) {
		gs.unstructuredTargets = { ":goto" };
	} else {
		gs.unstructuredTargets = p.unstructuredTargets;
	}
	
	return gs;
}

private ConstructorInfo makeCInfo(str tn, str cn, list[Symbol] parameters) {
	return cinfo(tn, cn, [ < pn, pt > | label(pn,pt) <- parameters ]);
}

@doc{Given the reified program type, return the types of each of the fields of all types/constructors in program}
public rel[str,str,ConstructorInfo] fieldTypes(type[&T] pgm) {
	return { < tn, cn, makeCInfo(tn,cn,ps) > | tt:\adt(tn,_) <- pgm.definitions<0>, /cons(\label(cn,tt),ps,_,_,_) := pgm.definitions<1> };
}

@doc{Given the reified program type, return the types reachable from a given type, e.g., by navigating fields}
public rel[Symbol,Symbol] reachableTypes(type[&T] pgm) {
	return { < tt, at > | tt:\adt(tn,_) <- pgm.definitions<0>, /cons(\label(cn,tt),ps,_,_,_) := pgm.definitions<1>, label(pn,pt) <- ps, at <- (pt + getADTs(pt)) }+;
}

@doc{Get any ADTs in the given type, including the type itself if it is an ADT}
public set[Symbol] getADTs(Symbol s) = { t | /t:\adt(_,_) := s};

@doc{Determine if we should recurse -- we should if we can reach an annotated ADT from the current type}
public bool shouldRecurse(GenState gs, Symbol t) {
	adtNames = { getADTName(at) | at <- getADTs(t) };
	if (!isEmpty(adtNames & gs.annotatedTypeNames)) return true;
	 
	rt = gs.reachableTypes[getADTs(t)];
	if (!isEmpty( { getADTName(t) | t <- rt, isADTType(t)} & gs.annotatedTypeNames )) return true;

	return false;	
}

public str escapeName(str s) {
	set[str] toEscape = { "o", "syntax", "keyword", "lexical", "int", "break", "continue", "rat", "true", 
		"bag", "num", "node", "finally", "private", "real", "list", "fail", "filter", "if", "tag", "extend", 
		"append", "rel", "lrel", "void", "non-assoc", "assoc", "test", "anno", "layout", "data", "join", 
		"it", "bracket", "in", "import", "false", "all", "dynamic", "solve", "type", "try", "catch", "notin", 
		"else", "insert", "switch", "return", "case", "while", "str", "throws", "visit", "tuple", "for", "assert", 
		"loc", "default", "map", "alias", "any", "module", "mod", "bool", "public", "one", "throw", "set", "start", 
		"datetime", "value" };
	if (s in toEscape) {
		return "\\" + s;
	} else {
		return s;
	}
}

public str escapeTypeName(str s) {
	set[str] toEscape = { "o", "syntax", "keyword", "lexical", "break", "continue", "true", 
		"bag", "finally", "private", "list", "fail", "filter", "if", "tag", "extend", 
		"append", "rel", "lrel", "non-assoc", "assoc", "test", "anno", "layout", "data", "join", 
		"it", "bracket", "in", "import", "false", "all", "dynamic", "solve", "type", "try", "catch", "notin", 
		"else", "insert", "switch", "return", "case", "while", "throws", "visit", "tuple", "for", "assert", 
		"default", "map", "alias", "any", "module", "mod", "public", "one", "throw", "set", "start" };
	if (s in toEscape) {
		return "\\" + s;
	} else {
		return s;
	}
}

public bool linkableType(Symbol ftype) {
	return (isListType(ftype) && isADTType(getListElementType(ftype))) || isADTType(ftype);
}

public ConstructorInfo getConstructorInfo(GenState gs, str tn, str cn, RuleArity ruleArity) {
	return getConstructorInfo(gs.fieldTypes, tn, cn, ruleArity);
}

public ConstructorInfo getConstructorInfo(GenState gs, str tn, str cn, RuleArity ruleArity) {
	return getConstructorInfo(gs.fieldTypes, tn, cn, ruleArity);
}

public ConstructorInfo getConstructorInfo(rel[str,str,ConstructorInfo] fieldTypes, str tn, str cn, RuleArity ruleArity) {
	// First, get back all constructors for the given type and constructor name
	cnSet = fieldTypes[tn,cn];
	if (isEmpty(cnSet)) {
		throw "Invalid type and constructor name, no constructor information found for <tn>::<cn>";
	}
	
	// Now, filter this based on the requested arity
	if (numeric(fieldCount) := ruleArity) {
		// If we have given a numeric arity, we need to filter to only keep constructors with the matching arity
		cnSet = { cni | cni <- cnSet, size(cni.consTypes) == fieldCount };
	} else if (fieldNames(fieldList) := ruleArity) {
		// If we have given field names, we keep only the constructors where the field names, as a set, match
		// the set of constructor field names. This should uniquely identify the constructor. TODO: this does
		// not account for keyword parameters.
		cnSet = { cni | cni <- cnSet, toSet(fieldList) == toSet(cni.consTypes<0>)}; 
	}
	
	// This should give us a unique constructor; if not, this is an error
	if (size(cnSet) != 1) {
		throw "The arity qualifier does not result in a unique constructor, it gives <size(cnSet)> alternatives";
	}
	
	return getOneFrom(cnSet);
}

public Symbol getTypeForName(GenState gs, str tn, str cn, RuleArity ruleArity, str name) {
	return getTypeForName(gs.fieldTypes, tn, cn, ruleArity, name);
}

public Symbol getTypeForName(rel[str,str,ConstructorInfo] fieldTypes, str tn, str cn, RuleArity ruleArity, str name) {
	cnInfo = getConstructorInfo(fieldTypes, tn, cn, ruleArity);
	fTypes = cnInfo.consTypes[name];
	
	// We should get back a single field type for the field
	if (size(fTypes) != 1) {
		throw "There is not a unique field name for field <name>, there are <size(fTypes)> alternatives";
	}

	return getOneFrom(fTypes);
}

public Symbol getTypeForName(GenState gs, Symbol tn, str name) {
	if (\adt(name,_) := tn) {
		return getTypeForName(gs.fieldTypes, name, ruleArity, name);
	}
	throw "Cannot navigate type <prettyPrintType(tn)>";
}

public Symbol getTypeForName(GenState gs, str tn, str name) {
	return getTypeForName(gs.fieldTypes, tn, ruleArity, name);
}

public Symbol getTypeForName(rel[str,str,ConstructorInfo] fieldTypes, str tn, str name) {
	// In Rascal, a field name must have the same type in all constructors for the same datatype. So,
	// we just have to look through the constructors until we find a hit.
	cnSet = fieldTypes[tn,cn];
	for (cItem <- cnSet, name in cItem.consTypes) {
		return getOneFrom(cItem.consTypes[name]);
	}
	throw "We were not able to find a field of that name in the constructor";
}

public type[&T] fetchTypeInfo(list[str] imports, str tname) {
	toRun = [ "import <mn>;" | mn <- imports ] + "#<tname>;";
	res = eval(#type[&T],toRun);
	return res.val;
}


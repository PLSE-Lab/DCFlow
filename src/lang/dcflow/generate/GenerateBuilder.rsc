@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::generate::GenerateBuilder

import lang::dcflow::ast::AbstractSyntax;
import lang::rascal::types::AbstractType;
import lang::dcflow::generate::GenerateUtils;
import lang::dcflow::generate::GenerateLabeler;

import Set;
import List;
import Type;
import IO;
import String;
import Node;

private bool hasFirstRuleItem(linkPart(RulePart from, RulePart to, set[str] edgeLabels)) = hasFirstRuleItem(from);
private bool hasFirstRuleItem(createPart(ItemName name)) = false;
private bool hasFirstRuleItem(jumpPart(RuleItem item)) = true;
private bool hasFirstRuleItem(jumpPart(RuleItem item, str targetType)) = true;
private bool hasFirstRuleItem(jumpToTargetPart(str targetType)) = false;
private bool hasFirstRuleItem(condPart(PredOp op, RulePart truePart, RulePart falsePart)) = hasFirstRuleItem(truePart);
private bool hasFirstRuleItem(nothing()) = false;
private bool hasFirstRuleItem(loopPart(str loopvar, RuleItem iterItem, RulePart body)) = true;
private bool hasFirstRuleItem(entryPart(list[RuleItem] items)) = size(items) > 0;
private bool hasFirstRuleItem(exitPart(list[RuleItem] items)) = size(items) > 0;
private bool hasFirstRuleItem(jumpTargetPart(RuleItem item)) = true;
private bool hasFirstRuleItem(jumpTargetPart(RuleItem item, str targetType)) = true;
private bool hasFirstRuleItem(namePart(RuleItem item)) = true;

private RuleItem getFirstRuleItem(linkPart(RulePart from, RulePart to, set[str] edgeLabels)) = getFirstRuleItem(from);
private RuleItem getFirstRuleItem(jumpPart(RuleItem item)) = item;
private RuleItem getFirstRuleItem(jumpPart(RuleItem item, str targetType)) = item;
private RuleItem getFirstRuleItem(entryPart(list[RuleItem] items)) = items[0];
private RuleItem getFirstRuleItem(exitPart(list[RuleItem] items)) = items[0];
private RuleItem getFirstRuleItem(jumpTargetPart(RuleItem item)) = item;
private RuleItem getFirstRuleItem(jumpTargetPart(RuleItem item, str targetType)) = item;
private RuleItem getFirstRuleItem(namePart(RuleItem item)) = item;

private bool hasLastRuleItem(linkPart(RulePart from, RulePart to, set[str] edgeLabels)) = hasLastRuleItem(to);
private bool hasLastRuleItem(createPart(ItemName name)) = false;
private bool hasLastRuleItem(jumpPart(RuleItem item)) = true;
private bool hasLastRuleItem(jumpPart(RuleItem item, str targetType)) = true;
private bool hasLastRuleItem(jumpToTargetPart(str targetType)) = false;
private bool hasLastRuleItem(condPart(PredOp op, RulePart truePart, RulePart falsePart)) = hasLastRuleItem(falsePart);
private bool hasLastRuleItem(nothing()) = false;
private bool hasLastRuleItem(loopPart(str loopvar, RuleItem iterItem, RulePart body)) = true;
private bool hasLastRuleItem(entryPart(list[RuleItem] items)) = size(items) > 0;
private bool hasLastRuleItem(exitPart(list[RuleItem] items)) = size(items) > 0;
private bool hasLastRuleItem(jumpTargetPart(RuleItem item)) = true;
private bool hasLastRuleItem(jumpTargetPart(RuleItem item, str targetType)) = true;
private bool hasLastRuleItem(namePart(RuleItem item)) = true;

private RuleItem getLastRuleItem(linkPart(RulePart from, RulePart to, set[str] edgeLabels)) = getLastRuleItem(to);
private RuleItem getLastRuleItem(jumpPart(RuleItem item)) = item;
private RuleItem getLastRuleItem(jumpPart(RuleItem item, str targetType)) = item;
private RuleItem getLastRuleItem(entryPart(list[RuleItem] items)) = items[-1];
private RuleItem getLastRuleItem(exitPart(list[RuleItem] items)) = items[-1];
private RuleItem getLastRuleItem(jumpTargetPart(RuleItem item)) = item;
private RuleItem getLastRuleItem(jumpTargetPart(RuleItem item, str targetType)) = item;
private RuleItem getLastRuleItem(namePart(RuleItem item)) = item;

private str nameQualifier(RuleArity::empty()) = "";
private str nameQualifier(RuleArity::numeric(int arity)) = "Arity<arity>";
private str nameQualifier(RuleArity::fieldNames(list[str] fnames)) = "Fields_<intercalate("_",fnames)>";

// TODO: Ensure we loop only over lists!

@doc{Generate the parameter pattern for a specific constructor (cn) of a specific type (tn)}
public str generateParameterPattern(GenState gs, str tn, str cn, RuleArity ruleArity) {
	cnInfo = getConstructorInfo(gs, tn, cn, ruleArity);
	str res = intercalate(",",["<escapeTypeName(prettyPrintType(unwrapType(pt)))> <escapeName(pn)>" | <pn,pt> <- cnInfo.consTypes ]);
	return "<escapeTypeName(tn)> item:<escapeName(cn)>(<res>)";
}

@doc{Return the field names declared for a specific constructor (cn) of a specific type (tn)}
public set[str] extractFieldNames(GenState gs, str tn, str cn, RuleArity ruleArity) {
	cnInfo = getConstructorInfo(gs, tn, cn, ruleArity);
	return toSet(cnInfo.consTypes<0>);
}

@doc{Generate code to get entry labels for named fields}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(fieldName(str name), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	resVar = gs.varNames["res"];

	str res = "";
	
	//if (isEmpty(gs.fieldTypes[tn,cn,ruleArity,name])) {
	//	println("ERROR: cannot find field types for <tn>::<cn><nameQualifier(ruleArity)>.<name>");
	//	return res;
	//}
	//

	// If the field has internal structure, we need to recurse to find the entry
	// label; e.g., for x + y, we would want the label for x
	recurse = shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,name));
	
	// If this is a list, we handle this specially
	fieldIsList = isListType(getTypeForName(gs,tn,cn,ruleArity,name));
	
	// Get back entry defaults; these are used if we cannot find an entry label
	// for this item, for instance if it references an empty list
	defaults = [ id | entryDefault(inames) <- itemInformation, id <- inames ];
	
	// Conditional handling for lists; we need to also check for emptiness.
	str genIf(list[ItemName] names) {
		str gires = "";
		str fstr = "";
		if (fieldName(gin) := names[0]) {
			if (shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,gin)) || isListType(getTypeForName(gs,tn,cn,ruleArity,gin))) {
				fstr = "entry(<escapeName(gin)>, <lsVar>)";
			} else {
				fstr = "<escapeName(gin)>@lab";
			}
		} else if (selfName() := names[0]) {
			fstr = "[ <itemVar>@lab ]";
		} else if (headerName() := names[0]) {
			fstr = "[ <lsVar>.headerNodes[<itemVar>@lab] ]";
		}
		
		if (size(names) > 1) {
			gires = "<resVar> = <fstr>;
					'if (isEmpty(<resVar>)) {
					'	<genIf(tail(names))>
					'} else {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		} else {
			gires = "<resVar> = <fstr>;
					'if (!isEmpty(<resVar>)) {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		}
		return gires;		
	}
	
	// Generate the entry label based on various conditions: is this a list,
	// are there defaults, should we recurse, etc
	if (fieldIsList && !isEmpty(defaults)) {
		res = genIf(fieldName(name) + defaults);
	} else if (fieldIsList) {
		res = "<labelsVar> = <labelsVar> + entry(<name>, <lsVar>);";
	} else if (recurse) {
		res = "<labelsVar> = <labelsVar> + entry(<name>, <lsVar>);";
	} else {
		res = "<labelsVar> = <labelsVar> + [ <name>@lab ];";
	}
	
	return res;
}

@doc{Generate the entry label for a compound item.}
// TODO: We currently assume the first position in the compound name is a field, not follow, etc.
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(compoundName(fieldName(str name), list[str] fieldPart), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	resVar = gs.varNames["res"];

	str res = "";
	str fullName = intercalate(".",name+fieldPart);
	
	// First, we need to get back the correct type for the compound name, which means we need to "run" the
	// field path.
	fieldType = getTypeForName(gs,tn,cn,ruleArity,name);
	for (fn <- fieldPart) {
		fieldType = getTypeForName(gs,fieldType,fn);
	}
	
	// If the field has internal structure, we need to recurse to find the entry
	// label; e.g., for x + y, we would want the label for x
	recurse = shouldRecurse(gs, fieldType);
	
	// If this is a list, we handle this specially
	fieldIsList = isListType(fieldType);
	
	// Get back entry defaults; these are used if we cannot find an entry label
	// for this item, for instance if it references an empty list
	defaults = [ id | entryDefault(inames) <- itemInformation, id <- inames ];
	
	// Conditional handling for lists; we need to also check for emptiness.
	str genIf(list[ItemName] names) {
		str gires = "";
		str fstr = "";
		if (fieldName(gin) := names[0]) {
			if (shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,gin)) || isListType(getTypeForName(gs,tn,cn,ruleArity,gin))) {
				fstr = "entry(<escapeName(gin)>, <lsVar>)";
			} else {
				fstr = "<escapeName(gin)>@lab";
			}
		} else if (selfName() := names[0]) {
			fstr = "[ <itemVar>@lab ]";
		} else if (headerName() := names[0]) {
			fstr = "[ <lsVar>.headerNodes[<itemVar>@lab] ]";
		}
		
		if (size(names) > 1) {
			gires = "<resVar> = <fstr>;
					'if (isEmpty(<resVar>)) {
					'	<genIf(tail(names))>
					'} else {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		} else {
			gires = "<resVar> = <fstr>;
					'if (!isEmpty(<resVar>)) {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		}
		return gires;		
	}
	
	// Generate the entry label based on various conditions: is this a list,
	// are there defaults, should we recurse, etc
	// TODO: We assume this is not currently used in cases where we have other defaults marked. Generalize this
	// logic to also handle field paths.
	//if (fieldIsList && !isEmpty(defaults)) {
	//	res = genIf(fieldName(name) + defaults);
	//} else 
	if (fieldIsList) {
		res = "<labelsVar> = <labelsVar> + entry(<fullName>, <lsVar>);";
	} else if (recurse) {
		res = "<labelsVar> = <labelsVar> + entry(<fullName>, <lsVar>);";
	} else {
		res = "<labelsVar> = <labelsVar> + [ <fullName>@lab ];";
	}
	
	return res;
}

@doc{Generate the entry label for self. This is the same as the label for the item.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(selfName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	return "<labelsVar> = <labelsVar> + <itemVar>@lab;";
}

@doc{Generate the entry label for following. This is the label for the link item created to represent this.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(followingName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + <lsVar>.linkNodes[<itemVar>@lab];";
}

@doc{Generate the entry label for first. This is the label of the first item of the current list (assuming one is available).}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(firstName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + entry(<gs.listStack[-1].listVar>[0],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the entry label for last. This is the label of the last item of the current list (assuming one is available).}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(lastName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + entry(<gs.listStack[-1].listVar>[-1],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the entry label for next. This is the label of the next item of the current list (assuming one is available).}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(nextName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + entry(<gs.listStack[-1].listVar>[<gs.listStack[-1].indexVar>],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the entry label for header. This is the label of the header node created for this item.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(headerName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	// TODO: This code assumes this exists, we should probably add a check
	return "<labelsVar> = <labelsVar> + <lsVar>.headerNodes[<itemVar>@lab];";
}

@doc{Generate the entry label for footer. This is the label of the footer node created for this item.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(footerName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	// TODO: This code assumes this exists, we should probably add a check
	return "<labelsVar> = <labelsVar> + <lsVar>.footerNodes[<itemVar>@lab];";
}

@doc{Generate the entry label for the exit node.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(exitName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + getExitNodeLabel(<lsVar>);";
}

@doc{Generate the entry label for the entry node.}
public str getEntryLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(entryName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + getEntryNodeLabel(<lsVar>);";
}

@doc{Generate code to get exit labels for field name items}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(fieldName(str name), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	resVar = gs.varNames["res"];
	lsVar = gs.varNames["ls"];

	str res = "";

	//if (isEmpty(gs.fieldTypes[tn,cn,name])) {
	//	println("ERROR: cannot find field types for <tn>::<cn>.<name>");
	//	return res;
	//}
	
	// If the field has internal structure, we need to recurse to find the entry
	// label; e.g., for x + y, we would want the label for x
	recurse = shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,name));
	
	// If this is a list, we handle this specially
	fieldIsList = isListType(getTypeForName(gs,tn,cn,ruleArity,name));

	// Get back entry defaults; these are used if we cannot find an entry label
	// for this item, for instance if it references an empty list
	defaults = [ id | exitDefault(inames) <- itemInformation, id <- inames ];
	
	// Conditional handling for lists; we need to also check for emptiness.
	str genIf(list[ItemName] names) {
		str gires = "";
		str fstr = "";
		if (fieldName(gin) := names[0]) {
			if (shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,gin)) || isListType(getTypeForName(gs,tn,cn,ruleArity,gin))) {
				fstr = "exit(<escapeName(gin)>, <lsVar>)";
			} else {
				fstr = "<escapeName(gin)>@lab";
			}
		} else if (selfName() := names[0]) {
			fstr = "{ <itemVar>@lab }";
		} else if (footerName() := names[0]) {
			fstr = "{ <lsVar>.footerNodes[<itemVar>@lab] }";
		} else if (followingName() := names[0]) {
			fstr = "{ <lsVar>.linkNodes[<itemVar>@lab] }";
		}
		
		// TODO: If we can use exit, etc as defaults, add them here
		
		if (size(names) > 1) {
			gires = "<resVar> = <fstr>;
					'if (isEmpty(<resVar>)) {
					'	<genIf(tail(names))>
					'} else {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		} else {
			gires = "<resVar> = <fstr>;
					'if (!isEmpty(<resVar>)) {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		}
		return gires;		
	}
	
	// Generate the entry label based on various conditions: is this a list,
	// are there defaults, should we recurse, etc
	if (fieldIsList && !isEmpty(defaults)) {
		res = genIf(fieldName(name) + defaults);
	} else if (fieldIsList) {
		res = "<labelsVar> = <labelsVar> + exit(<name>, <lsVar>);";
	} else if (recurse) {
		res = "<labelsVar> = <labelsVar> + exit(<name>, <lsVar>);";
	} else {
		res = "<labelsVar> = <labelsVar> + { <name>@lab };";
	}
	
	return res;
}

@doc{Generate the exit label for a compound item.}
// TODO: We currently assume the first position in the compound name is a field, not follow, etc.
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(compoundName(fieldName(str name), list[str] fieldPart), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	resVar = gs.varNames["res"];
	lsVar = gs.varNames["ls"];

	str res = "";
	str fullName = intercalate(".",name+fieldPart);
	
	// First, we need to get back the correct type for the compound name, which means we need to "run" the
	// field path.
	fieldType = getTypeForName(gs,tn,cn,ruleArity,name);
	for (fn <- fieldPart) {
		fieldType = getTypeForName(gs,fieldType,fn);
	}
	
	// If the field has internal structure, we need to recurse to find the entry
	// label; e.g., for x + y, we would want the label for x
	recurse = shouldRecurse(gs, fieldType);
	
	// If this is a list, we handle this specially
	fieldIsList = isListType(fieldType);

	// Get back entry defaults; these are used if we cannot find an entry label
	// for this item, for instance if it references an empty list
	defaults = [ id | exitDefault(inames) <- itemInformation, id <- inames ];
	
	// Conditional handling for lists; we need to also check for emptiness.
	str genIf(list[ItemName] names) {
		str gires = "";
		str fstr = "";
		if (fieldName(gin) := names[0]) {
			if (shouldRecurse(gs, getTypeForName(gs,tn,cn,ruleArity,gin)) || isListType(getTypeForName(gs,tn,cn,ruleArity,gin))) {
				fstr = "exit(<escapeName(gin)>, <lsVar>)";
			} else {
				fstr = "<escapeName(gin)>@lab";
			}
		} else if (selfName() := names[0]) {
			fstr = "{ <itemVar>@lab }";
		} else if (footerName() := names[0]) {
			fstr = "{ <lsVar>.footerNodes[<itemVar>@lab] }";
		} else if (followingName() := names[0]) {
			fstr = "{ <lsVar>.linkNodes[<itemVar>@lab] }";
		}
		
		// TODO: If we can use exit, etc as defaults, add them here
		
		if (size(names) > 1) {
			gires = "<resVar> = <fstr>;
					'if (isEmpty(<resVar>)) {
					'	<genIf(tail(names))>
					'} else {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		} else {
			gires = "<resVar> = <fstr>;
					'if (!isEmpty(<resVar>)) {
					'	<labelsVar> = <labelsVar> + <resVar>;
					'}";
		}
		return gires;		
	}
	
	// Generate the entry label based on various conditions: is this a list,
	// are there defaults, should we recurse, etc
	// TODO: We assume the first case does not happen yet, but alter code to handle it just in case
	//if (fieldIsList && !isEmpty(defaults)) {
	//	res = genIf(fieldName(name) + defaults);
	//} else 
	if (fieldIsList) {
		res = "<labelsVar> = <labelsVar> + exit(<fullName>, <lsVar>);";
	} else if (recurse) {
		res = "<labelsVar> = <labelsVar> + exit(<fullName>, <lsVar>);";
	} else {
		res = "<labelsVar> = <labelsVar> + { <fullName>@lab };";
	}
	
	return res;
}

@doc{Generate the exit label for self. This is the same as the label for the item.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(selfName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	return "<labelsVar> = <labelsVar> + <itemVar>@lab;";
}

@doc{Generate the exit label for following. This is the label for the link item created to represent this.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(followingName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + <lsVar>.linkNodes[<itemVar>@lab];";
}

@doc{Generate the exit label for first. This is the label of the first item of the current list (assuming one is available).}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(firstName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + exit(<gs.listStack[-1].listVar>[0],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the exit label for last. This is the label of the last item of the current list (assuming one is available).}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(lastName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + exit(<gs.listStack[-1].listVar>[-1],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the exit label for next. This is the label of the next item of the current list (assuming one is available).}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(nextName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	
	if (!isEmpty(gs.listStack)) {
		str res = 	"if (!isEmpty(<gs.listStack[-1].listVar>)) {
					'	<labelsVar> = <labelsVar> + entry(<gs.listStack[-1].listVar>[<gs.listStack[-1].indexVar>],<lsVar>);
					'}
					";
					
		return res;
	}

	return ""; 
}

@doc{Generate the exit label for header. This is the label of the header node created for this item.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(headerName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + <lsVar>.headerNodes[<itemVar>@lab];";
}

@doc{Generate the exit label for footer. This is the label of the footer node created for this item.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(footerName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + <lsVar>.footerNodes[<itemVar>@lab];";
}

@doc{Generate the exit label for the exit node.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(exitName(), set[ItemInfo] itemInformation)) {
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + getExitNodeLabel(<lsVar>);";
}

@doc{Generate the exit label for the exit node.}
public str getExitLabel(GenState gs, str tn, str cn, RuleArity ruleArity, ruleItem(entryName(), set[ItemInfo] itemInformation)) {
	// TODO: In theory we should never need this, since nothing links out of the exit node.
	labelsVar = gs.varNames["labels"];
	lsVar = gs.varNames["ls"];
	return "<labelsVar> = <labelsVar> + getEntryNodeLabel(<lsVar>);";
}

@doc{Generate the entry function for a given type/constructor}
public str generateEntryFunction(GenState gs, str tn, str cn, RuleArity ruleArity, list[RulePart] parts, bool isPrivate = true) {
	paramString = generateParameterPattern(gs, tn, cn, ruleArity);
	entryParts = { ep | /ep:entryPart(riList) := parts };
	markedItems = { ri | /ri:ruleItem(_,{entryLabel(),_*}) := parts};
	
	if ((size(entryParts) + size(markedItems)) > 1) {
		println("Warning: multiple entry declarations for <tn>::<cn>, chosing an arbitrary declaration");
	}
	 	
	list[str] entryItemElements = [ ];
	if (size(entryParts) > 0) {
		epart = getOneFrom(entryParts);
		entryItemElements = [ getEntryLabel(gs, tn, cn, ruleArity, item) | item <- epart.items ];
	} else if (size(markedItems) > 0) {
		entryItemElements = [ getEntryLabel(gs, tn, cn, ruleArity, getOneFrom(markedItems)) ];
	} else if (size(parts) == 1 && hasFirstRuleItem(parts[0]) && hasLastRuleItem(parts[0])) {
		entryItemElements = [ getEntryLabel(gs, tn, cn, ruleArity, getFirstRuleItem(parts[0])) ];
	}

	lsVar = gs.varNames["ls"];
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	validLabelsVar = gs.varNames["validLabels"];
	lVar = gs.varNames["l"];

	// TODO: Should also take account of arity here when checking the context
	res = "<isPrivate?"private":"public"> Lab entry(<paramString>, LabelState <lsVar>) {
	      '<if (<tn,cn,ruleArity> in gs.p.contexts) {>
		  '    if (<lsVar>.context.tn == \"<tn>\" && <lsVar>.context.cn == \"<cn>\") {
		  '<}> 
		  '        list[Lab] <labelsVar> = [ ];
		  '        if (<itemVar>@lab in <lsVar>.headerNodes) {
		  '            return <lsVar>.headerNodes[<itemVar>@lab];
		  '        }
		  '        <for (e <- entryItemElements) {><e>
		  '        <}>
		  '        <validLabelsVar> = [ <lVar> | <lVar> \<- <labelsVar>, !(<lVar> is nothing) ];
		  '        if (size(<validLabelsVar>) \> 0) {
		  '            return <validLabelsVar>[0];
		  '        }
		  '        <if(size(entryItemElements) > 0){>
		  '        return <itemVar>@lab;
		  '        <} else {>
		  '        return nothing();
		  '        <}>
	      '<if (<tn,cn,ruleArity> in gs.p.contexts) {>
		  '    } else {
		  '        return <itemVar>@lab;
		  '    }
		  '<}> 
		  '}";
	return res; 
}

@doc{Generate all the entry functions for the program p}
public str generateEntryFunctions(GenState gs, Program p, bool isPrivate = true) {
	rel[str,str,RuleArity,Rule] typeConsRel = { < r.targetType, r.targetCons, r.ruleArity, r > | r <- p.rules };
	list[str] entries = [ generateEntryFunction(gs, tn, cn, ruleArity, r.parts, isPrivate = true) | tn <- sort(toList(typeConsRel<0>)), cn <- sort(toList(typeConsRel[tn]<0>)), ruleArity <- typeConsRel[tn,cn]<0>, r <- typeConsRel[tn,cn,ruleArity] ];
	return intercalate("\n", entries);
}

@doc{Generate the exit function for a given type/constructor}
public str generateExitFunction(GenState gs, str tn, str cn, RuleArity ruleArity, list[RulePart] parts, bool isPrivate = true) {
	paramString = generateParameterPattern(gs, tn, cn, ruleArity);
	exitParts = { ep | /ep:exitPart(riList) := parts };
	markedItems = { ri | /ri:ruleItem(_,{exitLabel(),_*}) := parts};
	 	
	list[str] exitItemElements = [ getExitLabel(gs, tn, cn, ruleArity, item) | epart <- exitParts, item <- epart.items ] +
								 [ getExitLabel(gs, tn, cn, ruleArity, mi) | mi <- markedItems ];
								 
	if (size(exitItemElements) == 0 && size(parts) == 1 && hasFirstRuleItem(parts[0]) && hasLastRuleItem(parts[0])) {
		exitItemElements = [ getExitLabel(gs, tn, cn, ruleArity, getLastRuleItem(parts[0])) ]; 
	}

	lsVar = gs.varNames["ls"];
	labelsVar = gs.varNames["labels"];
	itemVar = gs.varNames["item"];
	validLabelsVar = gs.varNames["validLabels"];
	lVar = gs.varNames["l"];

	// TODO: Should also check arity here...
	res = "<isPrivate?"private":"public"> set[Lab] exit(<paramString>, LabelState <lsVar>) {
	      '<if (<tn,cn,ruleArity> in gs.p.contexts) {>
		  '    if (<lsVar>.context.tn == \"<tn>\" && <lsVar>.context.cn == \"<cn>\") {
		  '<}> 
		  '        if (<itemVar>@lab in <lsVar>.footerNodes) {
		  '            return { <lsVar>.footerNodes[<itemVar>@lab] };
		  '        }
		  '        if (<itemVar>@lab in <lsVar>.linkNodes) {
		  '            return { <lsVar>.linkNodes[<itemVar>@lab] };
		  '        }
		  '        set[Lab] <labelsVar> = { };
		  '        <for (e <- exitItemElements) {><e>
		  '        <}>
		  '        <if(size(exitItemElements) > 0){>
		  '        if (size(<labelsVar>) == 0) {
		  '            return { <itemVar>@lab };
		  '        }
		  '        <}>
		  '
		  '        return <labelsVar>;
	      '<if (<tn,cn,ruleArity> in gs.p.contexts) {>
		  '    } else {
		  '        return { <itemVar>@lab };
		  '    }
		  '<}> 
		  '}";
	return res; 
}

@doc{Generate all the exit functions for the program p}
public str generateExitFunctions(GenState gs, Program p, bool isPrivate = true) {
	rel[str,str,RuleArity,Rule] typeConsRel = { < r.targetType, r.targetCons, r.ruleArity, r > | r <- p.rules };
	list[str] entries = [ generateExitFunction(gs, tn, cn, ruleArity, r.parts, isPrivate = true) | tn <- sort(toList(typeConsRel<0>)), cn <- sort(toList(typeConsRel[tn]<0>)), ruleArity <- typeConsRel[tn,cn]<0>, r <- typeConsRel[tn,cn,ruleArity] ];
	return intercalate("\n", entries);
}

@doc{Generate the flow for a specific field; if it is a list or list relation, we add edges for each item in the list and between items, else we just add edges for the item}
list[str] flowForItem(GenState gs, str name, Symbol t) {
	list[str] res = [ ];
	
	lsVar = gs.varNames["ls"];
	edgesVar = gs.varNames["edges"];
	iVar = gs.varNames["i"];

	if (isListType(t)) {
		res = res + 
			"for(<iVar> \<- <name>) {
			'	\< <edgesVar>, <lsVar> \> = addEdges(<edgesVar>, <lsVar>, <iVar>);
			'}
			'\< <edgesVar>, <lsVar> \> = addSeqEdges(<edgesVar>, <lsVar>, <name>);"
			;   
	} else if (isADTType(t)) {
		res = res + "\< <edgesVar>, <lsVar> \> = addEdges(<edgesVar>, <lsVar>, <name>);";
	}
	
	return res;
}

data GenInfo = genInfo(list[str] body, bool entryLinkable, str entryLabel, bool exitLinkable, str exitLabels, GenState gs);

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, fieldName(str name)) {
	list[str] body = [ ];
	//if (isEmpty(gs.fieldTypes[tn,cn,name]) && !isForEachVar(gs, name)) {
	//	println("Field <name> not found under type <tn>, constructor <cn>");
	//} else if (!isEmpty(gs.fieldTypes[tn,cn,name])) {
	if (!isForEachVar(gs, name)) {
		ft = getTypeForName(gs,tn,cn,ruleArity,name);
		if (linkableType(ft)) {
			if (name notin gs.generatedFields) {
				gs.generatedFields = gs.generatedFields + name;
				body = body + flowForItem(gs,name,ft);
			}
			lsVar = gs.varNames["ls"];
			return genInfo(body, true, "entry(<name>,<lsVar>)", true, "exit(<name>,<lsVar>)", gs);
		}
	} else {
		ft = getListElementType(getTypeForName(gs,tn,cn,ruleArity,getForEachList(gs,name)));
		if (linkableType(ft)) {
			if (name notin gs.generatedFields) {
				gs.generatedFields = gs.generatedFields + name;
				body = body + flowForItem(gs,name,ft);
			}
			lsVar = gs.varNames["ls"];
			return genInfo(body, true, "entry(<name>,<lsVar>)", true, "exit(<name>,<lsVar>)", gs);
		}
	}
	return genInfo(body, false, "", false, "", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, compoundName(fieldName(str name), list[str] fieldPart)) {
	str fullName = intercalate(".",name+fieldPart);
	fieldType = getTypeForName(gs,tn,cn,ruleArity,name);
	for (fn <- fieldPart) {
		fieldType = getTypeForName(gs,fieldType,fn);
	}
	
	list[str] body = [ ];

	if (linkableType(fieldType)) {
		if (name notin gs.generatedFields) {
			gs.generatedFields = gs.generatedFields + fullName;
			body = body + flowForItem(gs,fullName,ft);
		}
		lsVar = gs.varNames["ls"];
		return genInfo(body, true, "entry(<fullName>,<lsVar>)", true, "exit(<fullName>,<lsVar>)", gs);
	}
	return genInfo(body, false, "", false, "", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, selfName()) {
	itemVar = gs.varNames["item"];
	return genInfo([], true, "<itemVar>@lab", true, "{<itemVar>@lab}", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, followingName()) {
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "<lsVar>.linkNodes[<itemVar>@lab]", true, "{<lsVar>.linkNodes[<itemVar>@lab]}", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, firstName()) {
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "entry(getFirstListEntry(<lsVar>),<lsVar>)", true, "exit(getFirstListEntry(<lsVar>),<lsVar>)", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, lastName()) {
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "entry(getLastListEntry(<lsVar>),<lsVar>)", true, "exit(getLastListEntry(<lsVar>),<lsVar>)", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, nextName()) {
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "entry(getNextListEntry(<lsVar>),<lsVar>)", true, "exit(getNextListEntry(<lsVar>),<lsVar>)", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, headerName()) {
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "<lsVar>.headerNodes[<itemVar>@lab]", true, "{<lsVar>.headerNodes[<itemVar>@lab]}", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, footerName()) {
	itemVar = gs.varNames["item"];
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "<lsVar>.footerNodes[<itemVar>@lab]", true, "{<lsVar>.footerNodes[<itemVar>@lab]}", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, exitName()) {
	lsVar = gs.varNames["ls"];
	return genInfo([], true, "getExitNode(<lsVar>)", false, "", gs);
}

public GenInfo generateFlowForItem(GenState gs, str tn, str cn, RuleArity ruleArity, entryName()) {
	lsVar = gs.varNames["ls"];
	return genInfo([], false, "", true, "{getEntryNode(<lsVar>)}", gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, namePart(RuleItem item)) {
	return generateFlowForItem(gs, tn, cn, ruleArity, item.itemName);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, linkPart(RulePart from, RulePart to, set[str] edgeLabels)) {
	giFrom = generateFlowForPart(gs, tn, cn, ruleArity, from);
	giTo = generateFlowForPart(giFrom.gs, tn, cn, ruleArity, to);
	gs = giTo.gs;
	 
	list[str] body = giFrom.body + giTo.body;
	labelsToAdd = intercalate(",",["<el>()"|el<-edgeLabels]);
	
	exlabVar = gs.varNames["exlab"];
	lsVar = gs.varNames["ls"];
	edgesVar = gs.varNames["edges"];
	
	if (giFrom.exitLinkable && giTo.entryLinkable) {
		body = body + "for(<exlabVar> \<- <giFrom.exitLabels>) {
		              '    \< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <exlabVar>, <giTo.entryLabel> <if(size(edgeLabels)>0){>,<labelsToAdd><}>);
		              '}";
	}

	return genInfo(body, giFrom.entryLinkable, giFrom.entryLabel, giTo.exitLinkable, giTo.exitLabels, gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, entryPart(list[RuleItem] items)) {
	return generateFlowForItem(gs, tn, cn, ruleArity, head(items).itemName);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, exitPart(list[RuleItem] items)) {
	return generateFlowForItem(gs, tn, cn, ruleArity, head(items).itemName);
}

public GenInfo createItem(GenState gs, str tn, str cn, RuleArity ruleArity, headerName()) {
	fnVar = gs.varNames["fn"];
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	
	str body = "if (<itemVar>@lab notin <lsVar>.headerNodes) {
			   '	\< <fnVar>, <lsVar> \> = createHeader(<lsVar>);
	           '    <lsVar>.headerNodes[<itemVar>@lab] = <fnVar>.l;
	           '}
	           '";
	return genInfo([body], true, "<lsVar>.headerNodes[<itemVar>@lab]", false, "", gs);
}

public GenInfo createItem(GenState gs, str tn, str cn, RuleArity ruleArity, footerName()) {
	fnVar = gs.varNames["fn"];
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	
	str body = "if (<itemVar>@lab notin <lsVar>.footerNodes) {
			   '	\< <fnVar>, <lsVar> \> = createFooter(<lsVar>);
	           '    <lsVar>.footerNodes[<itemVar>@lab] = <fnVar>.l;
	           '}
	           '";
	return genInfo([body], true, "<lsVar>.footerNodes[<itemVar>@lab]", false, "", gs);
}

public GenInfo createItem(GenState gs, str tn, str cn, RuleArity ruleArity, followingName()) {
	fnVar = gs.varNames["fn"];
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	
	str body = "if (<itemVar>@lab notin <lsVar>.linkNodes) {
			   '	\< <fnVar>, <lsVar> \> = createLink(<lsVar>);
	           '    <lsVar>.linkNodes[<itemVar>@lab] = <fnVar>.l;
	           '}
	           '";
	return genInfo([body], true, "<lsVar>.linkNodes[<itemVar>@lab]", false, "", gs);
}

public default GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, RulePart rp) {
	println("Warning, no support for rule part <rp>");
	return genInfo([],false,"",false,"", gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, createPart(ItemName iname)) {
	return createItem(gs, tn, cn, ruleArity, iname);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, jumpPart(RuleItem item)) {
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	targetLabelVar = gs.varNames["targetLabel"];
	targetLabelsVar = gs.varNames["targetLabels"];
	edgesVar = gs.varNames["edges"];
	
	if (item.itemName is fieldName) {
		str body = "<targetLabelsVar> = getTargetsForJump(<lsVar>, <item.itemName.name>);
				   'for (<targetLabelVar> \<- <targetLabelsVar>) {
				   '    \< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <itemVar>@lab, <targetLabelVar>, jump());
				   '}
				   '";
		return genInfo([body],true,"<itemVar>@lab",false,"",gs);
	} else if (item.itemName is exitName) {
		str body = "\< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <itemVar>@lab, getExitNodeLabel(<lsVar>), jump());";
		return genInfo([body],true,"<itemVar>@lab",false,"",gs);
	} else {
		println("<tn>::<cn>: Only field names are allowed to be jump targets, not <getName(item.itemName)>");
	}
	
	return genInfo([],false,"",false,"",gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, jumpPart(RuleItem item, str targetType)) {
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	targetLabelVar = gs.varNames["targetLabel"];
	targetLabelsVar = gs.varNames["targetLabels"];
	edgesVar = gs.varNames["edges"];

	if (item.itemName is fieldName) {
		str body = "<targetLabelsVar> = getTargetsForJump(<lsVar>, \"<targetType>\", <item.itemName.name>);
				   'for (<targetLabelVar> \<- <targetLabelsVar>) {
				   '    \< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <itemVar>@lab, <targetLabelVar>, jump());
				   '}
				   '";
		return genInfo([body],true,"<itemVar>@lab",false,"",gs);
	} else if (item.itemName is exitName) {
		println("WARNING: jumps to exit ignore the target");
		str body = "\< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <itemVar>@lab, getExitNodeLabel(<lsVar>), jump());";
		return genInfo([body],true,"<itemVar>@lab",false,"",gs);
	} else {
		println("<tn>::<cn>: Only field names are allowed to be jump targets, not <getName(item.itemName)>");
	}
	
	return genInfo([],false,"",false,"",gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, jumpToTargetPart(str targetType)) {
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	targetLabelVar = gs.varNames["targetLabel"];
	targetLabelsVar = gs.varNames["targetLabels"];
	edgesVar = gs.varNames["edges"];

	str body = "<targetLabelsVar> = getTargetsForJumpToTarget(<lsVar>, \"<targetType>\");
			   'for (<targetLabelVar> \<- <targetLabelsVar>) {
			   '    \< <edgesVar>, <lsVar> \> = linkItemsLabelLabel(<edgesVar>, <lsVar>, <itemVar>@lab, <targetLabelVar>, jump());
			   '}
			   '";
	return genInfo([body],true,"<itemVar>@lab",false,"",gs);
}

public str generatePredBody(GenState gs, emptyOp(ItemName iname)) {
	str res = "";
	
	if (fieldName(str name) := iname) {
		res = "isEmpty(name)";	
	} else if (compoundName(fieldName(str name), list[str] fieldPart) := iname) {
		res = "isEmpty(<intercalate(".",(name+fieldPart))>)";
	} else {
		println("WARNING: Unhandled predicate body for empty?, <iname>");
	}
	
	return res;
}

public str generatePredBody(GenState gs, firstOp(ItemName iname)) {
	str res = "";
	
	if (!isEmpty(gs.listStack)) {
		str res = "(<gs.listStack[-1].indexVar> == 0)";
	}

	return res;
}

public str generatePredBody(GenState gs, lastOp(ItemName iname)) {
	str res = "";
	
	if (!isEmpty(gs.listStack)) {
		str res = "(<gs.listStack[-1].indexVar> == (size(<gs.listStack[-1].listVar>) - 1))";
	}

	return res;
}

public str generatePredBody(GenState gs, isOp(ItemName iname, str consName)) {
	str res = "";
	
	if (fieldName(str name) := iname) {
		res = "<name> is <consName>";	
	} else if (compoundName(fieldName(str name), list[str] fieldPart) := iname) {
		res = "<intercalate(".",(name+fieldPart))> is <consName>";
	} else {
		println("WARNING: Unhandled predicate body for is, <iname>");
	}
	
	return res;
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, condPart(PredOp op, RulePart truePart, RulePart falsePart)) {
	str predBody = generatePredBody(gs, op);
	if (predBody != "") {
		trueFlow = generateFlowForPart(gs, tn, cn, ruleArity, truePart);
		falseFlow = generateFlowForPart(trueFlow.gs, tn, cn, ruleArity, falsePart);
		gs = falseFlow.gs;
		str body =	"if(<predBody>) { <intercalate("\n",trueFlow.body) >} else { <intercalate("\n",falseFlow.body)> }";
		return genInfo([body],false,"",false,"",gs);
	} else {
		return genInfo([],false,"",false,"",gs);
	}
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, nothing()) {
	return genInfo([],false,"",false,"",gs);
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, loopPart(str loopvar, RuleItem iterItem, RulePart body)) {
	// Get the item name, we only use a restricted set of all possible names; the checker should catch the rest
	str loopItem = "";
	if (ruleItem(fieldName(name),_) := iterItem) {
		loopItem = name;
	} else if (ruleItem(compoundName(fieldName(str name), list[str] fieldPart),_) := iterItem) {
		loopItem = "<intercalate(".",(name+fieldPart))>";
	}
	
	if (loopItem != "") {
		idxVar = "idx<size(gs.listStack+1)>";
		gs.listStack = gs.listStack + linfo(loopItem, loopvar, idxVar);
		bodyFlow = generateFlowForPart(gs, tn, cn, ruleArity, body);
		gs = bodyFlow.gs;
		bodyText = intercalate("\n",bodyFlow.body);
		if (size(trim(bodyText)) == 0) bodyText = ";";
		str res =	"for(<idxVar> \<- index(<loopItem>), <loopvar> := <loopItem>[idxVar]) {
					'<bodyText>
					'}
					";
		return genInfo([res],false,"",false,"",gs);
	} else {
		return genInfo([],false,"",false,"",gs);
	}
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, jumpTargetPart(RuleItem item)) {
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];
	
	gfi = genInfo([],false,"",false,"",gs);
	if (item.itemName is fieldName) {
		gfi.body = ["<lsVar> = createJumpTarget(<lsVar>, false, \"\", entry(<item.itemName.name>,<lsVar>), <itemVar>);"] + gfi.body;
	} else if (item.itemName is footerName) {
		gfi.body = ["<lsVar> = createJumpTarget(<lsVar>, false, \"\", <lsVar>.footerNodes[<itemVar>@lab], <itemVar>);"] + gfi.body;
	} else {
		println("<tn>::<cn>: Only field names are allowed to be jump targets, not <getName(item.itemName)>");
	}
	return gfi;	
}

public GenInfo generateFlowForPart(GenState gs, str tn, str cn, RuleArity ruleArity, jumpTargetPart(RuleItem item, str targetType)) {
	lsVar = gs.varNames["ls"];
	itemVar = gs.varNames["item"];

	gfi = genInfo([],false,"",false,"",gs);
	if (item.itemName is fieldName) {
		gfi.body = ["<lsVar> = createJumpTarget(<lsVar>, true, \"<targetType>\", entry(<item.itemName.name>,<lsVar>), <itemVar>);"] + gfi.body;
	} else if (item.itemName is footerName) {
		gfi.body = ["<lsVar> = createJumpTarget(<lsVar>, true, \"<targetType>\", <lsVar>.footerNodes[<itemVar>@lab], <itemVar>);"] + gfi.body;
	} else {
		println("<tn>::<cn>: Only field names are allowed to be jump targets, not <getName(item.itemName)>");
	}
	return gfi;
}

public str generateFlowFunction(GenState gs, str tn, str cn, RuleArity ruleArity, list[RulePart] parts, bool isPrivate=true) {
	// Move certain parts to beginning
	creations = [ cp | /cp:createPart(_) := parts ];
	followingFound = (/followingName() := parts);
	if (followingFound) creations = creations + createPart(followingName());
	parts = creations + parts;
	
	paramString = generateParameterPattern(gs, tn, cn, ruleArity);
	gs.generatedFields = { };
	list[str] body = [ ];
	for (part <- parts) {
		gfi = generateFlowForPart(gs, tn, cn, ruleArity, part);
		body = body + gfi.body;
		gs = gfi.gs;
	}
	//list[str] body = [b | part <- parts, b <- generateFlowForPart(gs, tn, cn, part).body ];
	
	lsVar = gs.varNames["ls"];
	edgesVar = gs.varNames["edges"];
	
	// If we add structured jump targets, we need to pop them as well
	list[str] targetsAdded = [ tt | /jumpTargetPart(_,tt) := parts, tt in gs.structuredTargets ];
	for (tt <- targetsAdded) {
		body = body + "<lsVar> = popStackLabel(<lsVar>, \"<tt>\");";
	}
	
	
	res = "<isPrivate?"private":"public"> tuple[FlowEdges,LabelState] internalFlow(<paramString>, LabelState <lsVar>) {
		  '    FlowEdges <edgesVar> = { };
		  '    <for(bi<-body){><bi>
		  '    <}>
		  '    return \< <edgesVar>, <lsVar> \>;
		  '}"; 

	gs.generatedFields = { };

	return res;
}

@doc{Generate all the flow functions for the program p}
public str generateFlowFunctions(GenState gs, Program p, bool isPrivate = true) {
	rel[str,str,RuleArity,Rule] typeConsRel = { < r.targetType, r.targetCons, r.ruleArity, r > | r <- p.rules };
	list[str] entries = [ generateFlowFunction(gs, tn, cn, ruleArity, r.parts, isPrivate = true) | tn <- sort(toList(typeConsRel<0>)), cn <- sort(toList(typeConsRel[tn]<0>)), ruleArity <- typeConsRel[tn,cn]<0>, r <- typeConsRel[tn,cn,ruleArity] ];
	return intercalate("\n", entries);
}

public str generateGraphBuilder(GenState gs, str tn, str cn, RuleArity ruleArity) {
	res = "private tuple[CFG,LabelState] create<tn><cn><nameQualifier(ruleArity)>CFG(<tn> item, loc itemLoc, LabelState ls) {
		  '    FlowEdges edges = { };
	      '    \< enode, ls \> = createEntry(ls);
	      '    \< xnode, ls \> = createExit(ls);
	      '    ls = addEntryExitNodes(ls, enode, xnode);
	      '
	      '    ls.jumpTargets = findUnstructuredJumpTargets(ls, item);
	      '
	      '    \< edges, ls \> = internalFlow(item, ls);
	      '    \< edges, ls \> = linkItemsLabelLabel(edges, ls, enode.l, entry(item,ls));
	      '    for (el \<- exit(item,ls)) {
	      '        \< edges, ls \> = linkItemsLabelLabel(edges, ls, el, xnode.l);
	      '    }
	      '
	      '    edges = addMissingEdgeLabels(ls, edges);
	      '    edges = consolidateEdges(edges);
	      '    edges = removeImpossibleEdges(edges);
	      '    \< edges, ls \> = removeLinks(edges, ls);
	      '
	      '    nodeMap = deriveNodeMap(ls,edges);
	      '    return \< cfg(itemLoc, nodeMap, edges, ls.labeledNodes), ls \>;
	      '}
	      '";

	return res;
}

public str generateGraphBuilders(GenState gs, str funname = "createCFG") {
	res = "public map[loc,CFG] <funname>(<gs.p.astType> p) {
		  '    map[loc,CFG] res = ( );
		  '    \< pLabeled, ls \> = labelAST(p);
		  '<for (<tn,cn,ruleArity> <- gs.p.contexts, <tn,cn,ruleArity> notin gs.p.ignores) {>
		  '    for (/<tn> item := pLabeled, item is <cn>) {
		  '        locForItem = getItemLoc(item);
		  '        ls.context = \< \"<tn>\", \"<cn>\" \>;
		  '        \< itemCFG, ls \> = create<tn><cn><nameQualifier(ruleArity)>CFG(item, locForItem, ls);
		  '        ls = resetLabelState(ls);
		  '        res[locForItem] = itemCFG; 
		  '    }
		  '<}>
		  '    return res;
		  '}
		  '";
		  
	for (<tn,cn,ruleArity> <- gs.p.contexts) {
		res = res + generateGraphBuilder(gs, tn, cn, ruleArity);
	}
	
	return res;
}

public str generateDCFlowModule(GenState gs, Program p, str mname, str funname="createCFG") {
	
	entryFunctions = generateEntryFunctions(gs, p);
	exitFunctions = generateExitFunctions(gs, p);
	flowFunctions = generateFlowFunctions(gs, p);
	labelingFunction = generateLabelingFunction(gs, p);
	builders = generateGraphBuilders(gs,funname=funname);
	
	str res = "module <mname>
			  '
			  'import lang::dcflow::base::CFG;
			  'import lang::dcflow::base::CFGExceptions;
			  'extend lang::dcflow::base::CFGUtils;
			  'import lang::dcflow::base::FlowEdge;
			  'import lang::dcflow::base::Label;
			  'import lang::dcflow::base::LabelState;
			  '
			  '<for(i<-p.astSources){>import <i>;<}>
			  '
			  '<for(i<-p.imports){>import <i>;<}>
			  '
			  'import Set;
			  'import List;
			  'import Type;
			  '
			  '<labelingFunction>
			  '
			  '<entryFunctions>
			  '
			  '<exitFunctions>
			  '
			  '<flowFunctions>
			  '
			  '<builders>
			  ";
	return res;
}

public void generateAndWriteDCFlowModule(GenState gs, Program p, str mname, loc l, str funname="createCFG") {
	writeFile(l+(replaceAll(mname,"::","/")+".rsc"),generateDCFlowModule(gs,p,mname,funname=funname));
}
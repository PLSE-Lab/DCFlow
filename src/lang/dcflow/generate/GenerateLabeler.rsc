@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::generate::GenerateLabeler

import lang::dcflow::ast::AbstractSyntax;
import lang::dcflow::generate::GenerateUtils;
import lang::dcflow::base::LabelState;
import lang::dcflow::base::CFG;
import lang::dcflow::base::Label;
import List;
import IO;
import String;

@doc{Generate the labeling function.}
public str generateLabelingFunction(GenState gs, Program p) {
	res = "private tuple[<p.astType>,LabelState] labelAST(<p.astType> ast) {
	      '    return labelAST(newLabelState(), ast);
	      '}
	      '
	      'private tuple[<p.astType>,LabelState] labelAST(LabelState ls, <p.astType> ast) {
		  '    Lab incLabel() { 
		  '        ls.counter += 1; 
		  '        return lab(ls.counter); 
		  '    }
		  '
		  '    labeledAst = bottom-up visit(ast) {
		  '        <for (n <- gs.annotatedTypeNames) {> case <n> n =\> n[@lab = incLabel()]
		  '        <}>
		  '    };
		  '
		  '    ls.cfgNodes = ( n@lab : cfgNode(n,n@lab) | /node n := labeledAst, (n@lab)?);
		  '
		  '    return \< labeledAst, ls \>;
	      '}";
	return res;	     		
}

//@doc{Generate the labeling module.}
//private str generateLabeler(GenState gs, Program p, str mname) {
//	res = "module <mname>
//		  '
//		  'import lang::dcflow::base::Label;
//		  'import lang::dcflow::base::LabelState;
//		  'import lang::dcflow::base::CFG;
//		  '<for (im <- (p.astSources + p.imports)){>import <im>;
//		  '<}>
//		  '
//		  '<generateLabelingFunction(gs, p)>
//		  '";
//	return res;
//}

//@doc{Generate the labeling module and write it to a file.}
//public void generateDCFlowLabeler(GenState gs, Program p, str mname, loc l) {
//	writeFile(l+(replaceAll(mname,"::","/")+".rsc"), generateLabeler(gs, p, mname));
//}
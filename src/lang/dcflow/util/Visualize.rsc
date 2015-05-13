@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::util::Visualize

import lang::dcflow::base::CFG;
import lang::dcflow::base::CFGExceptions;
import lang::dcflow::base::CFGUtils;
import lang::dcflow::base::FlowEdge;
import lang::dcflow::base::Label;
import lang::dcflow::base::LabelState;
import lang::dcflow::base::BasicBlocks;
import IO;
import List;
import Set;
import String;
import vis::Figure;
import vis::Render; 

//public void renderCFG(CFG c) {
//	str getID(CFGNode n) = "<n@lab>";
//	nodes = [ box(text("<escapeForDot(printCFGNode(n))>"), id(getID(n)), size(40)) | n <- c.nodes ];
//	edges = [ edge("<e.from>","<e.to>") | e <- c.edges ];
//	render(graph(nodes,edges,gap(40)));
//}

public str escapeForDot(str s) {
	return escape(s, ("\n" : "\\n", "\"" : "\\\""));
}

public void renderCFGAsDot(CFG c, loc writeTo, str(node) pp, bool addTitle = false, str title = "") {
	str getID(CFGNode n) = "<n.l>";
	
	nodes = [ "\"<getID(c.nodes[l])>\" [ label = \"[<l.id>]: <escapeForDot(printCFGNode(c.nodes[l],pp))>\", labeljust=\"l\" ];" | l <- c.nodes ];
	edges = [ "\"<e.from>\" -\> \"<e.to>\" [ label = \"<printEdgeLabel(e)>\"];" | e <- c.edges ];
	cfgTitle = "Control Flow Graph<size(title)>0?" for <title>":"">";
	str dotGraph = "digraph \"CFG\" {
				   '<if (addTitle){>graph [ label = \"<cfgTitle>\" ];<} else {>graph [ ];<}>
				   '	node [ shape = box ];
				   '	<intercalate("\n", nodes)>
				   '	<intercalate("\n",edges)>
				   '}";
	writeFile(writeTo,dotGraph);
}

@doc{Pretty-print CFG nodes}
public str printCFGNode(headerNode(Lab l),str(node) pp) = "header";
public str printCFGNode(footerNode(Lab l),str(node) pp) = "footer";
public str printCFGNode(entryNode(Lab l),str(node) pp) = "entry";
public str printCFGNode(exitNode(Lab l),str(node) pp) = "exit";
public str printCFGNode(linkNode(Lab l),str(node) pp) = "link";
public str printCFGNode(cfgNode(node n, Lab l),str(node) pp) = "<pp(n)>";
public str printCFGNode(basicBlock(list[CFGNode] nodes, Lab l), str(node)pp) 
	= intercalate("\\l", ["<printCFGNode(nodes[idx],pp)>"|idx<-index(nodes)])+"\\l";
public default str printCFGNode(CFGNode n,str(node) pp) = "CFGNode";

@doc{Print the contents of an edge label.}
public str printEdgeLabel(FlowEdge fe) = intercalate(",",[printEdgeLabel(el) | el <- fe.edgeLabels]);
public str printEdgeLabel(backedge()) = "back edge";
public str printEdgeLabel(conditionTrue()) = "true";
public str printEdgeLabel(conditionFalse()) = "false";
public str printEdgeLabel(jump()) = "jump";
public default str printEdgeLabel(EdgeLabel el) = "Edge";

@doc{Print lists of edge labels.}
public str printEdgeLabels(list[EdgeLabel] edgeLabels) = intercalate(",",[printEdgeLabel(el) | el <- edgeLabels]);

@doc{Print info that labels the flow edge.}
public str printFlowEdgeInfo(flowEdge(Lab from, Lab to, set[EdgeLabel] edgeLabels)) = "<printEdgeLabels(toList(edgeLabels))>";


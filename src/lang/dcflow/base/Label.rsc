@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::Label

@doc{Labels are added to AST nodes to give us a unique way to refer to each.}
data Lab = lab(int id) | nothing();

@doc{In theory, we can label any node.}
anno Lab node@lab;

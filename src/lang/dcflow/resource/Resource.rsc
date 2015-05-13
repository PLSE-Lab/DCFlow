module lang::dcflow::resource::Resource

import lang::dcflow::generate::GenerateAll;

@doc{Generator for CFG resources.}
@resource{cfg}
public str generate(str moduleName, loc uri) {
    map[str,str] options = uri.params;

    // We can pass the name of the function to generate. If we did, grab it then remove
    // it from the params.
    str funname = "buildCFGs";
    if ("funname" in options) {
        funname = options["funname"];
        options = domainX(options,{"funname"});
    }
        
    return generateAll(uri, modname=moduleName, funname=funname);
}
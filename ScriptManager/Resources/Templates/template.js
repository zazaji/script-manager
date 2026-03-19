// ScriptManager/Resources/Templates/template.js
#!/usr/bin/env node
// @Name: New Node Script
// @Desc: A sample script to demonstrate auto UI generation.
// @Author: You
// @Version: 1.0.0
// @Param: name | string | true | World | Who to greet
// @Param: verbose | bool | false | false | Enable verbose output

const args = process.argv.slice(2);
let name = "World";
let verbose = false;

args.forEach(arg => {
    if (arg === "--verbose") {
        verbose = true;
    } else {
        name = arg;
    }
});

if (verbose) {
    console.log("Verbose mode enabled.");
}

console.log(`Hello, ${name}!`);
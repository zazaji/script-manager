// ScriptManager/Resources/Samples/api_tester.js
#!/usr/bin/env node
// @Name: REST API Tester
// @Desc: Automated API testing utility with concurrent request support.
// @Author: ScriptManager
// @Version: 1.5.0
// @Param: endpoint | string | true | https://jsonplaceholder.typicode.com/todos/1 | API Endpoint URL
// @Param: method | choice | true | GET | HTTP Method | GET, POST, PUT, DELETE
// @Param: debug | bool | false | true | Print detailed request/response logs

const https = require('https');

console.log("🌐 Starting REST API Tester...");

const args = process.argv.slice(2);
let endpoint = args[0] || "https://jsonplaceholder.typicode.com/todos/1";
let method = args[1] || "GET";
let debug = args.includes("--debug");

console.log(`📡 Sending ${method} request to ${endpoint}...`);

const req = https.request(endpoint, { method: method }, (res) => {
    console.log(`\n📥 Status Code: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });
    
    res.on('end', () => {
        if (debug) {
            console.log("📦 Response Data:");
            try {
                const json = JSON.parse(data);
                console.log(JSON.stringify(json, null, 2));
            } catch (e) {
                console.log(data);
            }
        }
        console.log("\n✅ Test completed!");
    });
});

req.on('error', (error) => {
    console.error(`❌ Request failed: ${error.message}`);
});

req.end();
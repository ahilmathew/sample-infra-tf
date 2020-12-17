'use strict';
var express = require("express");
var exec = require('child_process').exec;
var app = express();

app.get("/logs", (req, res, next) => {
    var query = req.query.grep;
    var timeout = 10000;
    var logFile = "/etc/resource.log";
    console.log(query);
    if (!query) {
        res.sendFile(logFile);
    }
    else {
        exec(`cat ${logFile} | grep -i ${query}`, {
            timeout: timeout,
        }, function (err, output) {

            res.writeHead(200, { 'Content-Type': 'text/plain' });

            if (err || output == '') {
                res.end('No search results');
                console.log(err);
            }
            else {
                var results = output.split('\n');
                console.log(results);

                res.write('Search results\n');
                for (let i = 0; i < results.length; i++) {
                    res.write('\n');
                    res.write(results[i]);
                }
                res.end();
            }
        });
    }
});

app.listen(3000, () => {
    console.log("Server running on port 3000");
});
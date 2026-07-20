const http = require('node:http');

const port = process.env.PORT || 8080;

http.createServer((_req, res) => {
  res.writeHead(200, {'content-type': 'application/json'});
  res.end(JSON.stringify({
    message: process.env.WELCOME_MESSAGE || 'Hello from Cloud Run',
    environment: process.env.APP_ENV || 'unknown',
  }));
}).listen(port);

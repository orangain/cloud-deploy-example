const functions = require('@google-cloud/functions-framework');

functions.http('helloHttp', (req, res) => {
  res.json({
    message: 'Hello from a Cloud Run function',
    environment: process.env.ENVIRONMENT || 'unknown',
  });
});


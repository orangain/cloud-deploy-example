const functions = require('@google-cloud/functions-framework');

functions.http('helloHttp', (req, res) => {
  res.json({
    message: process.env.WELCOME_MESSAGE || 'Hello from a Cloud Run function',
    environment: process.env.APP_ENV || 'unknown',
  });
});

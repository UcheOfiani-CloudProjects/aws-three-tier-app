const express = require('express');
const db = require('./db');

const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('App is running and connected to RDS!');
});

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});

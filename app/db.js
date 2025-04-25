const mysql = require('mysql2');

const connection = mysql.createConnection({
  host: process.env.DB_HOST,
  user: 'admin',
  password: process.env.DB_PASSWORD,
  database: 'app_db'
});

connection.connect(err => {
  if (err) {
    console.error('DB connection failed:', err.stack);
    return;
  }
  console.log('Connected to database.');
});

module.exports = connection;

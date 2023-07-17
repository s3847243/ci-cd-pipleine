const express = require('express')
const bodyParser = require('body-parser')
const app = express()
const port = process.env.PORT

app.use(bodyParser.json())
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
)

app.set('view engine', 'ejs');

app.get('/health-check', (req, res) => {
  res.json({ info: 'Foo app is alive :-)' })
})

app.get('/', function(req, res) {
  res.render('pages/index');
});

static_demo_foos = [
    {name: "Big Foo", height: "201cm"},
    {name: "Little Foo", height: "30cm"}
];

// Configure connection to database
const Pool = require('pg').Pool
const pool = new Pool({
    user: process.env.DB_USERNAME,
    host: process.env.DB_HOSTNAME,
    database: 'foo',
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
})
console.log(pool);

app.get('/foos', function(req, res) {
    // Get list of foos and send response
    pool.query('SELECT * FROM foos ORDER BY id ASC', (error, results) => {
	if (error) {
	    throw error
	}
	res.render('pages/foos', {foos: results.rows});
    })
});

app.listen(port);
console.log(`Server is listening on port ${port}`);

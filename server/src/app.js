const express = require('express');
const routes = require('./routes');

const app = express();

// Monter toutes les routes API
app.use('/api', routes);

module.exports = app;
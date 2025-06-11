const express = require('express');
const routeController = require('./controllers/routeController');
const healthController = require('./controllers/healthController');

const app = express();

// Routes API
const apiRouter = express.Router();

// Routes principales
apiRouter.post('/routes/generate', routeController.generateRoute.bind(routeController));
apiRouter.post('/routes/alternative', routeController.generateAlternatives.bind(routeController));
apiRouter.post('/routes/analyze', routeController.analyzeRoute.bind(routeController));
apiRouter.get('/routes/export/:format', routeController.exportRoute.bind(routeController));
apiRouter.get('/routes/nearby-pois', routeController.getNearbyPOIs.bind(routeController));

// Health et status
apiRouter.get('/health', healthController.checkHealth);
apiRouter.get('/status', healthController.getStatus);

// Monter les routes
app.use('/api', apiRouter);

module.exports = app;
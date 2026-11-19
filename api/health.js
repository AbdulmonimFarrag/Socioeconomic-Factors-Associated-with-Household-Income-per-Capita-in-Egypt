'use strict';

const { dataEngine, model, fallbackModel, isConfigured } = require('../gemini-server');

module.exports = function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({
    ok: true,
    configured: isConfigured(),
    model,
    fallbackModel,
    engine: dataEngine.stats()
  });
};

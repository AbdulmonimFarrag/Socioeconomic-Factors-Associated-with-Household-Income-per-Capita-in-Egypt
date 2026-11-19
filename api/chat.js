'use strict';

const { askGemini, isConfigured } = require('../gemini-server');

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  if (!isConfigured()) {
    return res.status(503).json({ error: 'Gemini is not configured.' });
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const result = await askGemini(body);
    const { text, ...meta } = result;
    return res.status(200).json({ answer: text, meta });
  } catch (error) {
    const status = error.status === 429 ? 429 : error.status === 408 ? 504 : 500;
    return res.status(status).json({ error: error.message || 'Gemini request failed.' });
  }
};

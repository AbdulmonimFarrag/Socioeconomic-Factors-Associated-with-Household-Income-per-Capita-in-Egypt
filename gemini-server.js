// Thoth AI - hybrid local data engine + Gemini proxy (Node 18+, no npm packages)
const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { ThothDataEngine } = require('./thoth-data-engine');

const PORT = Number(process.env.PORT || 8765);
const KEY = process.env.GEMINI_API_KEY;
const MODEL = process.env.GEMINI_MODEL || 'gemini-3.5-flash';
const FALLBACK_MODEL = process.env.GEMINI_FALLBACK_MODEL || 'gemini-3.5-flash-lite';
const DIR = __dirname;
const WEB = fs.existsSync(path.join(DIR, 'dist')) ? path.join(DIR, 'dist') : DIR;
const DASHBOARD_FILE = path.join(WEB, 'index.html');
const DATA_ENGINE = new ThothDataEngine(DASHBOARD_FILE);

const SYSTEM_PROMPT = `You are Thoth AI, a natural conversational assistant embedded in the Egypt Household Survey 2021 dashboard.
- Reply naturally in the same language as the user. For Arabic, use friendly Egyptian Arabic unless the user uses formal Arabic.
- You can handle greetings, follow-up questions and normal conversation. Never repeat an introduction or dashboard summary unless asked.
- Keep typical answers concise: 2-4 short sentences, but give more detail when the user explicitly asks.
- Format analytical answers for a narrow chat panel: use short paragraphs and, when useful, up to 4 bullet points. Put headings such as **Insight** and **Recommendation** on their own lines; never run multiple headings together in one paragraph.
- When LOCAL DASHBOARD DATA is supplied, treat it as the only authoritative source for dashboard figures. Never invent, estimate or silently alter a number.
- If chartMatch is present, answer ONLY about that exact chart title and its current selections on the activeDashboard. Never substitute a similarly themed chart.
- If chartClarification is present, do not explain any chart yet; ask one short question naming the most relevant available chart titles.
- Explain figures clearly and mention the selected location/area/gender when it prevents ambiguity.
- Use conversation history to understand pronouns and follow-ups.
- If the requested dashboard fact is absent from the local data, say that briefly and ask one useful clarifying question.
- Suggested questions in the interface are examples only; the user may ask any question.`;

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp'
};

function send(res, code, obj) {
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store'
  });
  res.end(JSON.stringify(obj));
}

function compactHistory(history) {
  return (Array.isArray(history) ? history : [])
    .filter(item => item && item.text)
    .slice(-6)
    .map(item => ({
      role: item.role === 'model' ? 'model' : 'user',
      parts: [{ text: String(item.text).slice(0, 1200) }]
    }));
}

function geminiErrorMessage(data, status) {
  return (data && data.error && data.error.message) || `Gemini request failed (${status})`;
}

async function callModel(model, contents, timeoutMs = 20000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': KEY },
        signal: controller.signal,
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents,
          generationConfig: { maxOutputTokens: 1200, temperature: 0.35 }
        })
      }
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(geminiErrorMessage(data, response.status));
      error.status = response.status;
      throw error;
    }
    const parts = data.candidates?.[0]?.content?.parts || [];
    const text = parts.map(part => part.text || '').join('').trim();
    if (!text) throw new Error('Gemini returned an empty response.');
    return text;
  } catch (error) {
    if (error.name === 'AbortError') {
      const timeout = new Error(`Gemini timed out after ${Math.round(timeoutMs / 1000)} seconds.`);
      timeout.status = 408;
      throw timeout;
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function canRetry(error) {
  return [408, 429, 500, 502, 503, 504].includes(error.status);
}

async function askGemini({ message, context, history }) {
  const question = String(message || '').trim();
  if (!question) throw new Error('Please enter a message.');

  const retrieved = DATA_ENGINE.query(question, context || {}, history || []);
  const contents = compactHistory(history);
  const lastTurn = contents[contents.length - 1];
  if (lastTurn?.role === 'user' && lastTurn.parts[0].text.trim() === question) contents.pop();
  while (contents.length && contents[0].role !== 'user') contents.shift();

  const dataBlock = retrieved.dataUsed
    ? `LOCAL DASHBOARD DATA (computed locally from the complete dataset):\n${JSON.stringify(retrieved)}`
    : 'No dashboard figures were needed for this message. Respond as a normal conversational assistant.';
  contents.push({ role: 'user', parts: [{ text: `${dataBlock}\n\nCURRENT USER MESSAGE:\n${question}` }] });

  const attempts = MODEL === FALLBACK_MODEL ? [MODEL, MODEL] : [MODEL, FALLBACK_MODEL];
  let lastError;
  for (let index = 0; index < attempts.length; index += 1) {
    const model = attempts[index];
    try {
      const text = await callModel(model, contents);
      return {
        text,
        model,
        dataUsed: retrieved.dataUsed,
        retrievalMs: retrieved.retrievalMs,
        cacheHit: retrieved.cacheHit
      };
    } catch (error) {
      lastError = error;
      if (!canRetry(error) || index === attempts.length - 1) break;
    }
  }
  throw lastError;
}

function findDashboard() {
  if (fs.existsSync(DASHBOARD_FILE)) return 'index.html';
  const all = fs.readdirSync(WEB);
  return all.find(file => /^Thoth.*\.html$/i.test(file)) || all.find(file => file.endsWith('.html'));
}

const server = http.createServer(async (req, res) => {
  const route = req.url.split('?')[0];
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
    });
    return res.end();
  }

  if (req.method === 'GET' && route === '/api/health') {
    return send(res, 200, {
      ok: true,
      configured: Boolean(KEY),
      model: MODEL,
      fallbackModel: FALLBACK_MODEL,
      engine: DATA_ENGINE.stats()
    });
  }

  if (req.method === 'POST' && route === '/api/chat') {
    if (!KEY) return send(res, 503, { error: 'Gemini is not configured. Missing API key.' });
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 250000) req.destroy();
    });
    req.on('end', async () => {
      try {
        const result = await askGemini(JSON.parse(body || '{}'));
        send(res, 200, { answer: result.text, meta: result });
      } catch (error) {
        const status = error.status === 429 ? 429 : error.status === 408 ? 504 : 500;
        send(res, status, { error: error.message });
      }
    });
    return;
  }

  let name = decodeURIComponent(route);
  if (name === '/') name = '/' + findDashboard();
  const root = path.resolve(WEB);
  const file = path.resolve(WEB, '.' + name);
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory() || /\.(bat|ps1)$/i.test(file) || file === __filename) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end('Not found');
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

if (require.main === module) {
  server.listen(PORT, '127.0.0.1', () => {
    const url = `http://127.0.0.1:${PORT}/`;
    console.log(`Thoth AI running at ${url}`);
    console.log(`Models: ${MODEL} -> ${FALLBACK_MODEL}`);
    console.log(`Data engine: ${JSON.stringify(DATA_ENGINE.stats())}`);
    console.log(`Serving: ${WEB} -> ${findDashboard()}`);
    if (process.env.OPEN_BROWSER === '1') exec(`start "" "${url}"`);
  });
}

module.exports = {
  askGemini,
  dataEngine: DATA_ENGINE,
  model: MODEL,
  fallbackModel: FALLBACK_MODEL,
  isConfigured: () => Boolean(process.env.GEMINI_API_KEY)
};

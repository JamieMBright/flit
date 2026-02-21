// Vercel Serverless Function: Error Telemetry Endpoint
// POST /api/errors — Accept errors, store in memory + append to GitHub log
// GET  /api/errors — Retrieve errors from in-memory buffer
//
// Required env vars:
//   VERCEL_ERRORS_API_KEY  — Shared secret for X-API-Key auth
//   GITHUB_TOKEN           — GitHub PAT with repo:contents write scope
//   GITHUB_REPO            — e.g. "JamieMBright/flit"
//   GITHUB_LOG_PATH        — e.g. "logs/runtime-errors.jsonl"
//   GITHUB_BRANCH          — e.g. "main" (default)
//
// Architecture:
//   1. Flutter app POSTs errors here.
//   2. This function validates, enriches, and stores in memory for GET.
//   3. On POST, it also appends each error as a JSONL line to the GitHub
//      repo file via the GitHub Contents API. This gives durable persistence
//      without needing a database — errors land directly in the repo.
//   4. The fetch-errors.yml GitHub Action is kept as a fallback/reconciler
//      but is no longer the primary persistence path.

const MAX_STORED_ERRORS = 1000;
const MAX_PAYLOAD_ERRORS = 50;

// In-memory buffer for GET queries (survives within a single warm instance).
const errors = [];

const VALID_SEVERITIES = new Set(['critical', 'error', 'warning']);
const VALID_PLATFORMS = new Set(['web', 'ios', 'android']);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
};

// ---------------------------------------------------------------------------
// Privacy helpers
// ---------------------------------------------------------------------------

// Strip query parameters and hash from any URL string before logging.
// Returns just origin + pathname so tokens and analytics IDs are not stored.
function scrubUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.origin + parsed.pathname;
  } catch {
    // If the value isn't a parseable URL, return an empty string.
    return '';
  }
}

// Sensitive field-name prefixes that must never be logged.
const SENSITIVE_PREFIXES = ['token', 'key', 'secret', 'password', 'auth'];

// Scrub a context object in-place:
//   - Remove userAgent entirely (PII / browser fingerprint).
//   - Scrub the url field with scrubUrl().
//   - Remove any field whose name starts with a sensitive prefix.
function scrubContext(ctx) {
  if (typeof ctx !== 'object' || ctx === null) return ctx;
  const scrubbed = {};
  for (const [field, value] of Object.entries(ctx)) {
    if (field === 'userAgent') continue;
    const lower = field.toLowerCase();
    if (SENSITIVE_PREFIXES.some((prefix) => lower.startsWith(prefix))) continue;
    if (field === 'url') {
      scrubbed.url = scrubUrl(typeof value === 'string' ? value : '');
    } else {
      scrubbed[field] = value;
    }
  }
  return scrubbed;
}

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function isValidTimestamp(value) {
  if (!isNonEmptyString(value)) return false;
  const date = new Date(value);
  return !isNaN(date.getTime());
}

function validateErrorPayload(payload) {
  if (typeof payload !== 'object' || payload === null) {
    return 'Payload must be a non-null object';
  }
  if (!isValidTimestamp(payload.timestamp)) {
    return 'Invalid or missing "timestamp" (expected ISO 8601 string)';
  }
  if (!isNonEmptyString(payload.sessionId)) {
    return 'Invalid or missing "sessionId" (expected non-empty string)';
  }
  if (!isNonEmptyString(payload.appVersion)) {
    return 'Invalid or missing "appVersion" (expected non-empty string)';
  }
  if (!VALID_PLATFORMS.has(payload.platform)) {
    return `Invalid "platform" (expected one of: ${[...VALID_PLATFORMS].join(', ')})`;
  }
  if (!isNonEmptyString(payload.deviceInfo)) {
    return 'Invalid or missing "deviceInfo" (expected non-empty string)';
  }
  if (!VALID_SEVERITIES.has(payload.severity)) {
    return `Invalid "severity" (expected one of: ${[...VALID_SEVERITIES].join(', ')})`;
  }
  if (!isNonEmptyString(payload.error)) {
    return 'Invalid or missing "error" (expected non-empty string)';
  }
  if (payload.stackTrace !== undefined && typeof payload.stackTrace !== 'string') {
    return '"stackTrace" must be a string if provided';
  }
  if (payload.context !== undefined) {
    if (typeof payload.context !== 'object' || payload.context === null || Array.isArray(payload.context)) {
      return '"context" must be a plain object if provided';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

function authenticate(req) {
  const expectedKey = process.env.VERCEL_ERRORS_API_KEY;
  if (!expectedKey) return false;
  const providedKey = req.headers['x-api-key'];
  return providedKey === expectedKey;
}

// ---------------------------------------------------------------------------
// GitHub Contents API — append JSONL lines to the log file
// ---------------------------------------------------------------------------

async function appendToGitHub(newLines) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;
  const filePath = process.env.GITHUB_LOG_PATH || 'logs/runtime-errors.jsonl';
  const branch = process.env.GITHUB_BRANCH || 'main';

  // If GitHub integration isn't configured, skip silently.
  if (!token || !repo) return { ok: false, reason: 'github_not_configured' };

  const apiBase = `https://api.github.com/repos/${repo}/contents/${filePath}`;
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
    'User-Agent': 'flit-error-telemetry/1.0',
  };

  try {
    // 1. GET the current file to obtain its SHA (needed for updates).
    let existingContent = '';
    let sha = null;

    const getRes = await fetch(`${apiBase}?ref=${branch}`, { headers });

    if (getRes.ok) {
      const data = await getRes.json();
      sha = data.sha;
      existingContent = Buffer.from(data.content, 'base64').toString('utf-8');
    } else if (getRes.status === 404) {
      // File doesn't exist yet — will be created.
      existingContent = '';
      sha = null;
    } else {
      return { ok: false, reason: `github_get_failed_${getRes.status}` };
    }

    // 2. Append new JSONL lines.
    const separator = existingContent.length > 0 && !existingContent.endsWith('\n') ? '\n' : '';
    const updatedContent = existingContent + separator + newLines.join('\n') + '\n';

    // 3. PUT the updated file.
    const body = {
      message: `chore: append ${newLines.length} error(s) from telemetry`,
      content: Buffer.from(updatedContent).toString('base64'),
      branch,
    };
    if (sha) body.sha = sha;

    const putRes = await fetch(apiBase, {
      method: 'PUT',
      headers,
      body: JSON.stringify(body),
    });

    if (putRes.ok) {
      return { ok: true, linesAppended: newLines.length };
    }
    return { ok: false, reason: `github_put_failed_${putRes.status}` };
  } catch (err) {
    return { ok: false, reason: `github_error_${err.message}` };
  }
}

// ---------------------------------------------------------------------------
// POST handler
// ---------------------------------------------------------------------------

/// Normalize a lightweight JS-sourced error into the full schema.
/// JS errors only have { error, source, url, timestamp }.
/// We never log userAgent to avoid capturing personally identifiable info.
function normalizeJsPayload(payload) {
  if (!isNonEmptyString(payload.error)) return null;
  return {
    timestamp: payload.timestamp || new Date().toISOString(),
    sessionId: 'js-' + Date.now(),
    appVersion: 'web-js',
    platform: 'web',
    deviceInfo: 'web-browser',
    severity: 'critical',
    error: payload.error,
    stackTrace: payload.stackTrace || '',
    context: {
      source: payload.source || 'js_error_handler',
      url: payload.url || '',
    },
  };
}

async function handlePost(req, res) {
  const body = req.body;
  const payloads = Array.isArray(body) ? body : [body];

  if (payloads.length === 0) {
    return res.status(400).json({
      error: 'Empty payload',
      message: 'Request body must contain at least one error object',
    });
  }

  if (payloads.length > MAX_PAYLOAD_ERRORS) {
    return res.status(400).json({
      error: 'Payload too large',
      message: `Maximum ${MAX_PAYLOAD_ERRORS} errors per request`,
    });
  }

  const accepted = [];
  const rejected = [];

  for (let i = 0; i < payloads.length; i++) {
    let payload = payloads[i];
    const validationError = validateErrorPayload(payload);
    if (validationError) {
      // Try normalizing as a lightweight JS payload before rejecting.
      const normalized = normalizeJsPayload(payload);
      if (normalized) {
        payload = normalized;
      } else {
        rejected.push({ index: i, reason: validationError });
        continue;
      }
    }
    const enriched = {
      ...payload,
      context: scrubContext(payload.context),
      _receivedAt: new Date().toISOString(),
      _id: `${Date.now()}-${Math.random().toString(36).substring(2, 10)}`,
    };
    accepted.push(enriched);
  }

  // Store in memory for GET queries.
  for (const error of accepted) {
    errors.push(error);
  }
  while (errors.length > MAX_STORED_ERRORS) {
    errors.shift();
  }

  // Append to GitHub log file (non-blocking — don't fail the response).
  let githubResult = null;
  if (accepted.length > 0) {
    const jsonlLines = accepted.map((e) => JSON.stringify(e));
    try {
      githubResult = await appendToGitHub(jsonlLines);
    } catch {
      githubResult = { ok: false, reason: 'github_exception' };
    }
  }

  const status = rejected.length > 0 && accepted.length === 0 ? 400 : 200;

  return res.status(status).json({
    accepted: accepted.length,
    rejected: rejected.length,
    errors: rejected.length > 0 ? rejected : undefined,
    total: errors.length,
    github: githubResult,
  });
}

// ---------------------------------------------------------------------------
// GET handler
// ---------------------------------------------------------------------------

function handleGet(req, res) {
  const { since, limit: limitStr, severity } = req.query || {};

  let filtered = [...errors];

  if (since) {
    const sinceDate = new Date(since);
    if (isNaN(sinceDate.getTime())) {
      return res.status(400).json({
        error: 'Invalid "since" parameter',
        message: 'Expected ISO 8601 timestamp',
      });
    }
    filtered = filtered.filter((e) => new Date(e.timestamp) > sinceDate);
  }

  if (severity) {
    if (!VALID_SEVERITIES.has(severity)) {
      return res.status(400).json({
        error: 'Invalid "severity" parameter',
        message: `Expected one of: ${[...VALID_SEVERITIES].join(', ')}`,
      });
    }
    filtered = filtered.filter((e) => e.severity === severity);
  }

  let limit = parseInt(limitStr, 10);
  if (isNaN(limit) || limit < 1) limit = 100;
  limit = Math.min(limit, 500);

  const result = filtered.slice(-limit).reverse();

  return res.status(200).json({
    count: result.length,
    total: errors.length,
    errors: result,
  });
}

// ---------------------------------------------------------------------------
// Main router
// ---------------------------------------------------------------------------

module.exports = async (req, res) => {
  for (const [key, value] of Object.entries(corsHeaders)) {
    res.setHeader(key, value);
  }

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  // POST (error ingestion) is open — anyone can report errors.
  // GET (reading errors) requires auth to prevent data exposure.
  if (req.method === 'POST') {
    return handlePost(req, res);
  }

  if (!authenticate(req)) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid X-API-Key header',
    });
  }

  switch (req.method) {
    case 'GET':
      return handleGet(req, res);
    default:
      return res.status(405).json({
        error: 'Method not allowed',
        message: `${req.method} is not supported. Use GET or POST.`,
      });
  }
};

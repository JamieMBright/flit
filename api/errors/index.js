// Vercel Serverless Function: Error Telemetry Endpoint
// POST /api/errors — Accept and store error payloads
// GET  /api/errors — Retrieve errors with optional filtering
//
// Auth: X-API-Key header checked against VERCEL_ERRORS_API_KEY env var.
// Storage: In-memory array (resets on cold start). For persistence,
// replace with Vercel KV or an external database.

const MAX_STORED_ERRORS = 1000;
const MAX_PAYLOAD_ERRORS = 50;

// In-memory store (cleared on cold start / redeploy).
// For production persistence, swap with Vercel KV:
//   import { kv } from '@vercel/kv';
const errors = [];

// Valid severity values.
const VALID_SEVERITIES = new Set(['critical', 'error', 'warning']);

// Valid platform values.
const VALID_PLATFORMS = new Set(['web', 'ios', 'android']);

// CORS headers applied to every response.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
};

/**
 * Validate that a value is a non-empty string.
 */
function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Validate an ISO 8601 timestamp string.
 */
function isValidTimestamp(value) {
  if (!isNonEmptyString(value)) return false;
  const date = new Date(value);
  return !isNaN(date.getTime());
}

/**
 * Validate a single error payload against the expected schema.
 * Returns null if valid, or a string describing the first validation error.
 */
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

  // stackTrace is optional but must be a string if present.
  if (payload.stackTrace !== undefined && typeof payload.stackTrace !== 'string') {
    return '"stackTrace" must be a string if provided';
  }

  // context is optional but must be an object if present.
  if (payload.context !== undefined) {
    if (typeof payload.context !== 'object' || payload.context === null || Array.isArray(payload.context)) {
      return '"context" must be a plain object if provided';
    }
  }

  return null; // Valid
}

/**
 * Authenticate the request using the X-API-Key header.
 */
function authenticate(req) {
  const expectedKey = process.env.VERCEL_ERRORS_API_KEY;
  if (!expectedKey) {
    // If no key is configured, reject all requests to avoid open endpoints.
    return false;
  }
  const providedKey = req.headers['x-api-key'];
  return providedKey === expectedKey;
}

/**
 * Handle POST /api/errors — accept error payloads.
 * Accepts a single error object or an array of error objects.
 */
function handlePost(req, res) {
  const body = req.body;

  // Accept single object or array of objects.
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
    const payload = payloads[i];
    const validationError = validateErrorPayload(payload);

    if (validationError) {
      rejected.push({ index: i, reason: validationError });
    } else {
      // Add server-side metadata.
      const enriched = {
        ...payload,
        _receivedAt: new Date().toISOString(),
        _id: `${Date.now()}-${Math.random().toString(36).substring(2, 10)}`,
      };
      accepted.push(enriched);
    }
  }

  // Store accepted errors, evicting oldest if over capacity.
  for (const error of accepted) {
    errors.push(error);
  }
  while (errors.length > MAX_STORED_ERRORS) {
    errors.shift();
  }

  const status = rejected.length > 0 && accepted.length === 0 ? 400 : 200;

  return res.status(status).json({
    accepted: accepted.length,
    rejected: rejected.length,
    errors: rejected.length > 0 ? rejected : undefined,
    total: errors.length,
  });
}

/**
 * Handle GET /api/errors — retrieve stored errors with optional filtering.
 * Query params:
 *   - since: ISO 8601 timestamp (only return errors after this time)
 *   - limit: Maximum number of errors to return (default 100, max 500)
 *   - severity: Filter by severity level
 */
function handleGet(req, res) {
  const { since, limit: limitStr, severity } = req.query || {};

  let filtered = [...errors];

  // Filter by timestamp if 'since' is provided.
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

  // Filter by severity if provided.
  if (severity) {
    if (!VALID_SEVERITIES.has(severity)) {
      return res.status(400).json({
        error: 'Invalid "severity" parameter',
        message: `Expected one of: ${[...VALID_SEVERITIES].join(', ')}`,
      });
    }
    filtered = filtered.filter((e) => e.severity === severity);
  }

  // Apply limit (default 100, max 500).
  let limit = parseInt(limitStr, 10);
  if (isNaN(limit) || limit < 1) {
    limit = 100;
  }
  limit = Math.min(limit, 500);

  // Return newest first, limited.
  const result = filtered.slice(-limit).reverse();

  return res.status(200).json({
    count: result.length,
    total: errors.length,
    errors: result,
  });
}

/**
 * Main handler — routes by HTTP method.
 */
module.exports = (req, res) => {
  // Set CORS headers on every response.
  for (const [key, value] of Object.entries(corsHeaders)) {
    res.setHeader(key, value);
  }

  // Handle CORS preflight.
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  // Authenticate.
  if (!authenticate(req)) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid X-API-Key header',
    });
  }

  // Route by method.
  switch (req.method) {
    case 'POST':
      return handlePost(req, res);
    case 'GET':
      return handleGet(req, res);
    default:
      return res.status(405).json({
        error: 'Method not allowed',
        message: `${req.method} is not supported. Use GET or POST.`,
      });
  }
};

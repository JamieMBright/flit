// Vercel Serverless Function: Health Check
// GET /api/health — Returns service status (no auth required)
//
// Also pings Supabase to keep the free-tier project from pausing
// (Supabase pauses after 7 days of inactivity). Vercel cron hits
// this endpoint every 3 days via the "crons" config in vercel.json.

// Supabase project details (public/client-side values — safe to embed).
const SUPABASE_URL = 'https://zrffgpkscdaybfhujioc.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_AnlV4Gngx7a5z3KwqV7F9w_-4rQYEJs';

/**
 * Lightweight Supabase ping — hits the PostgREST health endpoint.
 * Returns { ok, latencyMs } on success or { ok, error } on failure.
 */
async function pingSupabase() {
  const start = Date.now();
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/`, {
      method: 'HEAD',
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      },
    });
    const latencyMs = Date.now() - start;
    return { ok: res.status < 500, status: res.status, latencyMs };
  } catch (err) {
    return { ok: false, error: err.message, latencyMs: Date.now() - start };
  }
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const hasApiKey = !!process.env.VERCEL_ERRORS_API_KEY;
  const hasGithubToken = !!process.env.GITHUB_TOKEN;
  const hasGithubRepo = !!process.env.GITHUB_REPO;

  // Ping Supabase to keep the free-tier project active.
  const supabase = await pingSupabase();

  return res.status(200).json({
    status: 'ok',
    service: 'flit-error-telemetry',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    config: {
      apiKeyConfigured: hasApiKey,
      githubIntegration: hasGithubToken && hasGithubRepo,
      logPath: process.env.GITHUB_LOG_PATH || 'logs/runtime-errors.jsonl',
      branch: process.env.GITHUB_BRANCH || 'main',
    },
    supabase,
  });
};

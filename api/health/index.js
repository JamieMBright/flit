// Vercel Serverless Function: Health Check
// GET /api/health — Returns service status (no auth required)

module.exports = (req, res) => {
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
  });
};

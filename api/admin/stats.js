// Vercel Serverless Function: Admin Usage Stats
// GET /api/admin/stats — Returns aggregated platform usage statistics
//
// Requires X-API-Key header (same key as /api/errors).
// Queries Supabase directly for player counts, activity windows,
// game volume, and matchmaking pool status.

const SUPABASE_URL = 'https://zrffgpkscdaybfhujioc.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_AnlV4Gngx7a5z3KwqV7F9w_-4rQYEJs';

const HEADERS = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
  'Content-Type': 'application/json',
};

/** Run a PostgREST query and return the parsed JSON (or null on error). */
async function query(path) {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      headers: { ...HEADERS, Prefer: 'return=representation' },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** Count rows matching a PostgREST filter. */
async function count(table, filter = '') {
  try {
    const url = `${SUPABASE_URL}/rest/v1/${table}?select=*${filter}`;
    const res = await fetch(url, {
      method: 'HEAD',
      headers: { ...HEADERS, Prefer: 'count=exact' },
    });
    const total = res.headers.get('content-range');
    if (!total) return 0;
    // content-range: 0-N/TOTAL  or  */TOTAL
    const match = total.match(/\/(\d+)$/);
    return match ? parseInt(match[1], 10) : 0;
  } catch {
    return 0;
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

  // Auth check — same API key as /api/errors
  const apiKey = req.headers['x-api-key'];
  const expectedKey = process.env.VERCEL_ERRORS_API_KEY;
  if (!expectedKey || apiKey !== expectedKey) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const now = new Date();
  const iso = (d) => d.toISOString();

  // Time windows
  const h1 = new Date(now - 1 * 60 * 60 * 1000);
  const h24 = new Date(now - 24 * 60 * 60 * 1000);
  const d7 = new Date(now - 7 * 24 * 60 * 60 * 1000);
  const d30 = new Date(now - 30 * 24 * 60 * 60 * 1000);

  // Run all queries in parallel
  const [
    totalPlayers,
    signups24h,
    signups7d,
    signups30d,
    totalGames,
    games1h,
    games24h,
    games7d,
    games30d,
    activeChallenges,
    matchmakingPool,
    topPlayers,
    recentScores,
  ] = await Promise.all([
    // Player counts
    count('profiles'),
    count('profiles', `&created_at=gte.${iso(h24)}`),
    count('profiles', `&created_at=gte.${iso(d7)}`),
    count('profiles', `&created_at=gte.${iso(d30)}`),

    // Game volume
    count('scores'),
    count('scores', `&created_at=gte.${iso(h1)}`),
    count('scores', `&created_at=gte.${iso(h24)}`),
    count('scores', `&created_at=gte.${iso(d7)}`),
    count('scores', `&created_at=gte.${iso(d30)}`),

    // Active challenges & matchmaking
    count('challenges', '&status=in.(pending,in_progress)'),
    count('matchmaking_pool', '&matched_at=is.null'),

    // Top players by games played (for leaderboard snapshot)
    query('profiles?select=username,level,xp,coins,games_played,best_score,best_time_ms&order=games_played.desc&limit=10'),

    // Recent game activity (last 20 scores for activity feed)
    query('scores?select=score,time_ms,region,rounds_completed,created_at,user_id&order=created_at.desc&limit=20'),
  ]);

  // Compute active players (distinct users who played in each window)
  // We approximate this from scores data — a player who submitted a score was active
  let activePlayers1h = 0;
  let activePlayers24h = 0;
  let activePlayers7d = 0;
  if (recentScores) {
    const uniqueUsers1h = new Set();
    const uniqueUsers24h = new Set();
    for (const s of recentScores) {
      const t = new Date(s.created_at);
      if (t >= h1) uniqueUsers1h.add(s.user_id);
      if (t >= h24) uniqueUsers24h.add(s.user_id);
    }
    activePlayers1h = uniqueUsers1h.size;
    activePlayers24h = uniqueUsers24h.size;
  }

  return res.status(200).json({
    timestamp: iso(now),
    players: {
      total: totalPlayers,
      signups_24h: signups24h,
      signups_7d: signups7d,
      signups_30d: signups30d,
    },
    activity: {
      games_total: totalGames,
      games_1h: games1h,
      games_24h: games24h,
      games_7d: games7d,
      games_30d: games30d,
      active_players_1h: activePlayers1h,
      active_players_24h: activePlayers24h,
    },
    social: {
      active_challenges: activeChallenges,
      matchmaking_pool_size: matchmakingPool,
    },
    top_players: topPlayers || [],
    recent_games: (recentScores || []).slice(0, 10),
  });
};

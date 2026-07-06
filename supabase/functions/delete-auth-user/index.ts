import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Child tables that reference a user, deleted (with the service role, so RLS
// cannot block us) before the auth.users row is removed. Order does not matter
// for the service role, but we keep profiles last to mirror the client cascade.
// Each entry is [table, column-holding-the-user-id]. `friendships` and
// `challenges` reference the user under two columns and are handled specially.
const USER_TABLES: Array<[string, string]> = [
  ['scores', 'user_id'],
  ['account_state', 'user_id'],
  ['user_settings', 'user_id'],
  ['iap_receipts', 'user_id'],
  ['gdpr_requests', 'user_id'],
  ['profiles', 'id'],
]

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Identify the caller from their JWT.
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user: caller } } = await userClient.auth.getUser()
  if (!caller) return new Response('Unauthorized', { status: 401 })

  let user_id: string | undefined
  try {
    const body = await req.json()
    user_id = body?.user_id
  } catch (_) {
    return new Response('Missing user_id', { status: 400 })
  }
  if (!user_id) return new Response('Missing user_id', { status: 400 })

  // Authorize: a user may always delete THEMSELVES; an owner may delete anyone.
  // Self-deletion is checked against the JWT identity, so it does NOT depend on
  // the caller's `profiles` row still existing — this is what lets a normal
  // account be fully removed.
  let authorized = caller.id === user_id
  if (!authorized) {
    const { data: profile } = await userClient
      .from('profiles')
      .select('admin_role')
      .eq('id', caller.id)
      .single()
    authorized = profile?.admin_role === 'owner'
  }
  if (!authorized) {
    return new Response('Forbidden: may only delete your own account', {
      status: 403,
    })
  }

  // Service-role client bypasses RLS and does not depend on any profile row.
  const adminClient = createClient(supabaseUrl, serviceRoleKey)

  // Run the FULL data cascade server-side so deletion is authoritative even if
  // the client already removed (or never had a chance to remove) these rows.
  // Best-effort per table: a missing table (e.g. blocked_users not yet migrated)
  // must not abort the whole deletion.
  const cascadeErrors: string[] = []

  async function safeDelete(fn: () => Promise<{ error: unknown }>, label: string) {
    try {
      const { error } = await fn()
      if (error) cascadeErrors.push(`${label}: ${JSON.stringify(error)}`)
    } catch (e) {
      cascadeErrors.push(`${label}: ${String(e)}`)
    }
  }

  // Two-column relationship tables.
  await safeDelete(
    () => adminClient.from('friendships').delete()
      .or(`requester_id.eq.${user_id},addressee_id.eq.${user_id}`),
    'friendships',
  )
  await safeDelete(
    () => adminClient.from('challenges').delete()
      .or(`challenger_id.eq.${user_id},challenged_id.eq.${user_id}`),
    'challenges',
  )
  // Blocks the user made or received (table may not exist yet).
  await safeDelete(
    () => adminClient.from('blocked_users').delete()
      .or(`blocker_id.eq.${user_id},blocked_id.eq.${user_id}`),
    'blocked_users',
  )
  // Single-column tables.
  for (const [table, column] of USER_TABLES) {
    await safeDelete(
      () => adminClient.from(table).delete().eq(column, user_id),
      table,
    )
  }

  // Finally remove the auth.users row (the email). This is the step the client
  // cannot perform, so it is the whole reason this function exists.
  const { error: authError } = await adminClient.auth.admin.deleteUser(user_id)
  if (authError) {
    return new Response(
      JSON.stringify({ error: authError.message, cascadeErrors }),
      { status: 500 },
    )
  }

  return new Response(
    JSON.stringify({ success: true, cascadeErrors }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
})

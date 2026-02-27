import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Edge Function: reset-user-password
 *
 * Triggers a password reset email for a user. Requires moderator or owner role.
 * Uses the admin API to send the reset link regardless of rate limits.
 */
serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Verify caller is at least a moderator
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user: caller } } = await userClient.auth.getUser()
  if (!caller) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const { data: profile } = await userClient
    .from('profiles')
    .select('admin_role')
    .eq('id', caller.id)
    .single()

  if (!profile?.admin_role) {
    return new Response(JSON.stringify({ error: 'Forbidden: admin only' }), { status: 403 })
  }

  const { user_id } = await req.json()
  if (!user_id) {
    return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 })
  }

  // Use service role to get the user's email, then send reset
  const adminClient = createClient(supabaseUrl, serviceRoleKey)
  const { data: targetUser, error: getUserError } = await adminClient.auth.admin.getUserById(user_id)
  if (getUserError || !targetUser?.user?.email) {
    return new Response(
      JSON.stringify({ error: getUserError?.message ?? 'User not found or no email' }),
      { status: 404 },
    )
  }

  const { error: resetError } = await adminClient.auth.admin.generateLink({
    type: 'recovery',
    email: targetUser.user.email,
  })

  if (resetError) {
    return new Response(JSON.stringify({ error: resetError.message }), { status: 500 })
  }

  // Log the action
  await userClient.rpc('_log_admin_action', {
    p_action: 'trigger_password_reset',
    p_target_id: user_id,
    p_details: { triggered_by: caller.id },
  })

  return new Response(
    JSON.stringify({ success: true, email: targetUser.user.email }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
})

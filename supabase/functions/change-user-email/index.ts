import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Edge Function: change-user-email
 *
 * Changes a user's email address. Owner-only. Used for account recovery
 * when a player is locked out of their email.
 */
serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Verify caller is an owner
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

  if (profile?.admin_role !== 'owner') {
    return new Response(JSON.stringify({ error: 'Forbidden: owner only' }), { status: 403 })
  }

  const { user_id, new_email } = await req.json()
  if (!user_id || !new_email) {
    return new Response(
      JSON.stringify({ error: 'Missing user_id or new_email' }),
      { status: 400 },
    )
  }

  // Use service role to update the user's email directly
  const adminClient = createClient(supabaseUrl, serviceRoleKey)
  const { error: updateError } = await adminClient.auth.admin.updateUserById(user_id, {
    email: new_email,
    email_confirm: true, // Skip email confirmation since this is admin-initiated
  })

  if (updateError) {
    return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
  }

  // Log the action
  await userClient.rpc('_log_admin_action', {
    p_action: 'change_user_email',
    p_target_id: user_id,
    p_details: { new_email, changed_by: caller.id },
  })

  return new Response(
    JSON.stringify({ success: true }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
})

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Verify the request comes from an authenticated admin
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Verify caller is admin using their JWT
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user: caller } } = await userClient.auth.getUser()
  if (!caller) return new Response('Unauthorized', { status: 401 })

  const { data: profile } = await userClient.from('profiles').select('admin_role').eq('id', caller.id).single()
  if (profile?.admin_role !== 'owner') return new Response('Forbidden: owner only', { status: 403 })

  const { user_id } = await req.json()
  if (!user_id) return new Response('Missing user_id', { status: 400 })

  // Use service role client to delete auth user
  const adminClient = createClient(supabaseUrl, serviceRoleKey)
  const { error } = await adminClient.auth.admin.deleteUser(user_id)
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 })

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})

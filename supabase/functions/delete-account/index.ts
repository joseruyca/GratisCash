import { createClient } from 'npm:@supabase/supabase-js@2.117.2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type StorageEntry = {
  id?: string | null
  name: string
  metadata?: unknown | null
}

async function collectFiles(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  path: string,
): Promise<string[]> {
  const result: string[] = []
  let offset = 0

  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(path, {
      limit: 100,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    })

    if (error) throw new Error(`Unable to list storage bucket ${bucket}`)

    const entries = (data ?? []) as StorageEntry[]
    if (entries.length === 0) break

    for (const entry of entries) {
      const fullPath = path ? `${path}/${entry.name}` : entry.name
      const looksLikeFolder = entry.id == null && entry.metadata == null
      if (looksLikeFolder) {
        result.push(...await collectFiles(admin, bucket, fullPath))
      } else {
        result.push(fullPath)
      }
    }

    if (entries.length < 100) break
    offset += entries.length
  }

  return result
}

async function purgeUserStorage(
  admin: ReturnType<typeof createClient>,
  userId: string,
) {
  for (const bucket of ['avatars', 'opportunity-images']) {
    const paths = await collectFiles(admin, bucket, userId)
    for (let i = 0; i < paths.length; i += 100) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100))
      if (error) throw new Error(`Unable to delete storage objects from ${bucket}`)
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  const jwt = authHeader.slice('Bearer '.length).trim()
  const url = Deno.env.get('SUPABASE_URL')
  const publishable =
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!url || !publishable || !serviceRole) {
    return new Response('Server configuration error', { status: 500, headers: corsHeaders })
  }

  const userClient = createClient(url, publishable, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  const admin = createClient(url, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    await purgeUserStorage(admin, user.id)

    const { error: signOutError } = await admin.auth.admin.signOut(jwt)
    if (signOutError) {
      console.error('Session revocation failed', signOutError.message)
      return new Response('Account deletion failed', { status: 500, headers: corsHeaders })
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
    if (deleteError) {
      console.error('Auth user deletion failed', deleteError.message)
      return new Response('Account deletion failed', { status: 500, headers: corsHeaders })
    }

    return Response.json({ ok: true }, { headers: corsHeaders })
  } catch (error) {
    console.error('Account deletion failed', error)
    return new Response('Account deletion failed', { status: 500, headers: corsHeaders })
  }
})

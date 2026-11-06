const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "Method not allowed" });
  }

  const authorization = req.headers.get("authorization") ?? "";
  const jwt = authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";

  if (!jwt) {
    return json(401, { ok: false, error: "Unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  if (!supabaseUrl || !anonKey) {
    return json(503, { ok: false, error: "Server configuration error" });
  }

  let body: Record<string, unknown>;

  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(400, { ok: false, error: "Invalid request" });
    }
    body = parsed;
  } catch {
    return json(400, { ok: false, error: "Invalid JSON" });
  }

  const deviceId = body.device_id;
  const platform = body.platform;
  const token = body.token;

  if (
    typeof deviceId !== "string" ||
    typeof platform !== "string" ||
    typeof token !== "string" ||
    deviceId.trim().length === 0 ||
    deviceId.length > 128 ||
    token.trim().length === 0 ||
    token.length > 8192 ||
    !["ios", "android", "web"].includes(platform)
  ) {
    return json(400, { ok: false, error: "Invalid device registration" });
  }

  try {
    const response = await fetch(
      `${supabaseUrl.replace(/\/+$/, "")}/rest/v1/rpc/app_push_register_device`,
      {
        method: "POST",
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${jwt}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          p_device_id: deviceId.trim(),
          p_platform: platform,
          p_token: token.trim(),
        }),
      },
    );

    if (response.status === 401 || response.status === 403) {
      return json(401, { ok: false, error: "Unauthorized" });
    }

    if (!response.ok) {
      return json(400, {
        ok: false,
        error: "Device registration rejected",
      });
    }

    return json(200, { ok: true });
  } catch {
    return json(503, { ok: false, error: "Registration unavailable" });
  }
});

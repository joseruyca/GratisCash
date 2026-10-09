import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SITE = "https://gratiscashv1.vercel.app";

function xml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return new Response("Service unavailable", { status: 503 });
  }

  const endpoint = new URL("/rest/v1/opportunities_public", supabaseUrl);
  endpoint.searchParams.set("select", "id,updated_at");
  endpoint.searchParams.set("order", "updated_at.desc");
  endpoint.searchParams.set("limit", "1000");

  const response = await fetch(endpoint, {
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${anonKey}`,
      accept: "application/json",
    },
  });
  if (!response.ok) {
    return new Response("Service unavailable", { status: 503 });
  }

  const rows = await response.json();
  const urls = [
    `<url><loc>${xml(SITE + "/")}</loc></url>`,
    ...(Array.isArray(rows) ? rows : []).map((row: Record<string, unknown>) =>
      `<url><loc>${xml(`${SITE}/o/${row.id}`)}</loc>${row.updated_at ? `<lastmod>${xml(String(row.updated_at).slice(0,10))}</lastmod>` : ""}</url>`
    ),
  ];

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.join("")}</urlset>`;

  if (req.method === "HEAD") {
    return new Response(null, {
      status: 200,
      headers: {
        "content-type": "application/xml; charset=utf-8",
        "cache-control": "public, max-age=600, s-maxage=1800",
      },
    });
  }

  return new Response(body, {
    headers: {
      "content-type": "application/xml; charset=utf-8",
      "cache-control": "public, max-age=600, s-maxage=1800, stale-while-revalidate=3600",
      "x-content-type-options": "nosniff",
    },
  });
});

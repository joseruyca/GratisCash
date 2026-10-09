import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SITE = "https://gratiscashv1.vercel.app";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function esc(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function compact(value: unknown, max = 165): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  return text.slice(0, max - 1).trimEnd() + "…";
}

function htmlResponse(
  status: number,
  title: string,
  description: string,
  headExtra: string,
  body: string,
  robots: string,
): Response {
  const html = `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta name="robots" content="${esc(robots)}">
<meta name="theme-color" content="#009B70">
${headExtra}
</head>
<body>${body}</body>
</html>`;

  return new Response(html, {
    status,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": status === 200
        ? "public, max-age=300, s-maxage=900, stale-while-revalidate=3600"
        : "public, max-age=60",
      "x-content-type-options": "nosniff",
      "referrer-policy": "strict-origin-when-cross-origin",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const requestUrl = new URL(req.url);
  const id = (requestUrl.searchParams.get("id") ?? "").trim();

  if (!UUID_RE.test(id)) {
    if (req.method === "HEAD") return new Response(null, { status: 404 });
    return htmlResponse(
      404,
      "Oportunidad no encontrada · GratisCash",
      "La oportunidad solicitada no está disponible.",
      "",
      "<main><h1>Oportunidad no encontrada</h1></main>",
      "noindex,nofollow",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return new Response("Service unavailable", { status: 503 });
  }

  const endpoint = new URL("/rest/v1/opportunities_public", supabaseUrl);
  endpoint.searchParams.set(
    "select",
    "id,title,description,source_name,reward_text,category,effective_status,image_url,updated_at,author_name",
  );
  endpoint.searchParams.set("id", `eq.${id}`);
  endpoint.searchParams.set("limit", "1");

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
  const item = Array.isArray(rows) ? rows[0] : null;
  if (!item) {
    if (req.method === "HEAD") return new Response(null, { status: 404 });
    return htmlResponse(
      404,
      "Oportunidad no encontrada · GratisCash",
      "La oportunidad solicitada no está disponible.",
      "",
      "<main><h1>Oportunidad no encontrada</h1></main>",
      "noindex,nofollow",
    );
  }

  if (req.method === "GET") {
    const userAgent = (req.headers.get("user-agent") ?? "").toLowerCase();
    const looksLikeBot = /(bot|crawler|spider|facebookexternalhit|twitterbot|whatsapp|telegrambot|discordbot|slackbot|preview)/i.test(
      userAgent,
    );

    if (!looksLikeBot) {
      try {
        await fetch(new URL("/rest/v1/rpc/register_landing_visit", supabaseUrl), {
          method: "POST",
          headers: {
            apikey: anonKey,
            authorization: `Bearer ${anonKey}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({ p_opportunity_id: id }),
        });
      } catch (_) {
        // Analytics are deliberately best-effort.
      }
    }
  }

  const canonical = `${SITE}/o/${id}`;
  const appUrl = `${SITE}/opportunity/${id}`;
  const titleText = compact(item.title, 78);
  const description = compact(
    item.description || `${item.reward_text ?? ""} en ${item.source_name ?? "GratisCash"}`,
    165,
  );
  const reward = compact(item.reward_text, 80);
  const source = compact(item.source_name, 80);
  const image = typeof item.image_url === "string" && item.image_url.startsWith("https://")
    ? item.image_url
    : null;
  const ended = item.effective_status === "expired";

  const structured = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "WebPage",
    name: titleText,
    description,
    url: canonical,
    isPartOf: {
      "@type": "WebSite",
      name: "GratisCash",
      url: SITE,
    },
    dateModified: item.updated_at,
    about: {
      "@type": "Thing",
      name: source || titleText,
    },
  }).replaceAll("<", "\\u003c");

  const headExtra = `
<link rel="canonical" href="${esc(canonical)}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="GratisCash">
<meta property="og:locale" content="es_ES">
<meta property="og:title" content="${esc(titleText)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${esc(canonical)}">
${image ? `<meta property="og:image" content="${esc(image)}"><meta name="twitter:card" content="summary_large_image">` : '<meta name="twitter:card" content="summary">'}
<meta name="twitter:title" content="${esc(titleText)}">
<meta name="twitter:description" content="${esc(description)}">
<script type="application/ld+json">${structured}</script>
<style>
  :root{color-scheme:light;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
  *{box-sizing:border-box}
  body{margin:0;background:#f7f9f9;color:#102235}
  main{max-width:760px;margin:0 auto;padding:24px}
  .brand{font-size:24px;font-weight:900;color:#102235;text-decoration:none}
  .brand span{color:#00a67a}
  .card{margin-top:24px;background:#fff;border:1px solid #e3e9e8;border-radius:24px;overflow:hidden;box-shadow:0 8px 30px rgba(16,34,53,.05)}
  img{display:block;width:100%;max-height:360px;object-fit:cover}
  .content{padding:24px}
  .eyebrow{font-size:12px;font-weight:800;color:#7657d6;text-transform:uppercase;letter-spacing:.06em}
  h1{font-size:32px;line-height:1.08;margin:8px 0 12px}
  .reward{font-size:24px;font-weight:900;color:#00a67a;margin:8px 0}
  .meta{color:#667487;font-size:14px}
  p{line-height:1.6;color:#45566a}
  .cta{display:inline-flex;margin-top:18px;background:#00a67a;color:white;text-decoration:none;font-weight:900;padding:13px 18px;border-radius:14px}
  .ended{display:inline-block;background:#eef1f2;color:#667487;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:800}
</style>`;

  const body = `<main>
<a class="brand" href="${SITE}"><span>◆</span> GratisCash</a>
<article class="card">
  ${image ? `<img src="${esc(image)}" alt="">` : ""}
  <div class="content">
    <div class="eyebrow">Oportunidad en GratisCash</div>
    <h1>${esc(titleText)}</h1>
    ${reward ? `<div class="reward">${esc(reward)}</div>` : ""}
    <div class="meta">${esc(source)}${ended ? ' · <span class="ended">Terminada</span>' : ""}</div>
    <p>${esc(description)}</p>
    <a class="cta" href="${esc(appUrl)}">Ver oportunidad en GratisCash</a>
  </div>
</article>
</main>`;

  if (req.method === "HEAD") {
    return new Response(null, {
      status: 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, max-age=300, s-maxage=900",
      },
    });
  }

  return htmlResponse(
    200,
    `${titleText} · GratisCash`,
    description,
    headExtra,
    body,
    "index,follow,max-image-preview:large",
  );
});

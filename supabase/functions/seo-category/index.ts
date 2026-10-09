import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SITE = "https://gratiscashv1.vercel.app";

const CATEGORIES: Record<string, { value: string; title: string; description: string }> = {
  dinero: {
    value: "money",
    title: "Oportunidades para ganar dinero",
    description: "Descubre oportunidades reales para conseguir dinero, recompensas económicas y pagos por acciones sencillas.",
  },
  gratis: {
    value: "freeProduct",
    title: "Productos y cosas gratis",
    description: "Encuentra muestras, productos, pruebas y promociones con las que puedes conseguir cosas gratis.",
  },
  cashback: {
    value: "cashback",
    title: "Cashback y reembolsos",
    description: "Descubre oportunidades de cashback y reembolso para recuperar parte de tus compras y gastos.",
  },
  bonus: {
    value: "bonus",
    title: "Bonos y recompensas",
    description: "Encuentra bonos de bienvenida, puntos, incentivos y recompensas disponibles en distintas plataformas.",
  },
  misiones: {
    value: "mission",
    title: "Misiones y tareas remuneradas",
    description: "Descubre misiones, tareas y acciones concretas con las que puedes conseguir recompensas o dinero.",
  },
};

function esc(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function compact(value: unknown, max = 150): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  return text.slice(0, max - 1).trimEnd() + "…";
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const requestUrl = new URL(req.url);
  const slug = (requestUrl.searchParams.get("slug") ?? "").toLowerCase();
  const category = CATEGORIES[slug];

  if (!category) {
    return new Response("<!doctype html><html lang=\"es\"><head><meta name=\"robots\" content=\"noindex,nofollow\"><title>Categoría no encontrada · GratisCash</title></head><body><h1>Categoría no encontrada</h1></body></html>", {
      status: 404,
      headers: {
        "content-type": "text/html; charset=utf-8",
        "x-content-type-options": "nosniff",
      },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return new Response("Service unavailable", { status: 503 });
  }

  const endpoint = new URL("/rest/v1/opportunities_public", supabaseUrl);
  endpoint.searchParams.set(
    "select",
    "id,title,description,source_name,reward_text,image_url,vote_score,updated_at",
  );
  endpoint.searchParams.set("category", `eq.${category.value}`);
  endpoint.searchParams.set("effective_status", "eq.active");
  endpoint.searchParams.set("order", "is_featured.desc,vote_score.desc,created_at.desc");
  endpoint.searchParams.set("limit", "30");

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
  const items = Array.isArray(rows) ? rows : [];
  const canonical = `${SITE}/c/${slug}`;
  const shouldIndex = items.length > 0;

  const structured = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: category.title,
    description: category.description,
    url: canonical,
    isPartOf: {
      "@type": "WebSite",
      name: "GratisCash",
      url: SITE,
    },
    mainEntity: {
      "@type": "ItemList",
      itemListElement: items.map((item: Record<string, unknown>, index: number) => ({
        "@type": "ListItem",
        position: index + 1,
        url: `${SITE}/o/${item.id}`,
        name: item.title,
      })),
    },
  }).replaceAll("<", "\\u003c");

  const cards = items.map((item: Record<string, unknown>) => {
    const title = compact(item.title, 90);
    const description = compact(item.description, 150);
    const reward = compact(item.reward_text, 70);
    const source = compact(item.source_name, 60);
    const image = typeof item.image_url === "string" && item.image_url.startsWith("https://")
      ? item.image_url
      : null;

    return `<article class="card">
      ${image ? `<img src="${esc(image)}" alt="" loading="lazy">` : ""}
      <div class="card-body">
        <div class="source">${esc(source)}</div>
        <h2>${esc(title)}</h2>
        ${reward ? `<div class="reward">${esc(reward)}</div>` : ""}
        <p>${esc(description)}</p>
        <a href="${SITE}/o/${esc(item.id)}">Ver oportunidad</a>
      </div>
    </article>`;
  }).join("");

  if (req.method === "HEAD") {
    return new Response(null, {
      status: 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, max-age=300, s-maxage=900",
      },
    });
  }

  const html = `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(category.title)} · GratisCash</title>
<meta name="description" content="${esc(category.description)}">
<meta name="robots" content="${shouldIndex ? "index,follow,max-image-preview:large" : "noindex,follow"}">
<link rel="canonical" href="${esc(canonical)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="GratisCash">
<meta property="og:locale" content="es_ES">
<meta property="og:title" content="${esc(category.title)}">
<meta property="og:description" content="${esc(category.description)}">
<meta property="og:url" content="${esc(canonical)}">
<meta name="theme-color" content="#009B70">
<script type="application/ld+json">${structured}</script>
<style>
  :root{font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#102235;background:#f7f9f9}
  *{box-sizing:border-box}
  body{margin:0}
  main{max-width:1100px;margin:auto;padding:24px}
  .brand{font-size:24px;font-weight:900;color:#102235;text-decoration:none}.brand span{color:#00a67a}
  .hero{padding:48px 0 28px;max-width:760px}
  h1{font-size:42px;line-height:1.05;margin:0 0 14px} .hero p{font-size:18px;line-height:1.6;color:#536477}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}
  .card{background:white;border:1px solid #e3e9e8;border-radius:22px;overflow:hidden;box-shadow:0 6px 24px rgba(16,34,53,.04)}
  .card img{width:100%;height:160px;object-fit:cover}.card-body{padding:18px}.source{font-size:12px;color:#6a7888;font-weight:700}
  h2{font-size:20px;line-height:1.2;margin:7px 0 9px}.reward{font-size:18px;font-weight:900;color:#00a67a}.card p{color:#536477;line-height:1.45}
  .card a{display:inline-flex;margin-top:5px;color:#007e5f;font-weight:900;text-decoration:none}
  .empty{padding:28px;background:white;border:1px solid #e3e9e8;border-radius:20px;color:#536477}
</style>
</head>
<body>
<main>
<a class="brand" href="${SITE}"><span>◆</span> GratisCash</a>
<section class="hero">
  <h1>${esc(category.title)}</h1>
  <p>${esc(category.description)}</p>
</section>
${items.length ? `<section class="grid">${cards}</section>` : '<div class="empty">Ahora mismo no hay oportunidades activas en esta categoría. Vuelve pronto.</div>'}
</main>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300, s-maxage=900, stale-while-revalidate=3600",
      "x-content-type-options": "nosniff",
      "referrer-policy": "strict-origin-when-cross-origin",
    },
  });
});

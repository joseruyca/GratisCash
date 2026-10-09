# GratisCash V15 · 1.13.0+15

## SEO y adquisición
- Sitemap XML dinámico con oportunidades públicas.
- Landing HTML indexable por oportunidad en /o/:id.
- Open Graph y Twitter Cards con título, descripción e imagen reales.
- Datos estructurados WebPage para buscadores.
- Enlaces compartidos apuntan a la landing SEO y desde ella a la app.
- Canonical y WebSite structured data en la portada.
- robots.txt declara sitemap y evita rastreo de áreas privadas.

## Seguridad
- Las funciones SEO son públicas porque deben acceder crawlers, pero solo leen opportunities_public.
- No usan service_role ni acceden a schemas privados.
- Los IDs se validan como UUID.
- Todo contenido procedente de oportunidades se escapa antes de insertarse en HTML/XML.
- Respuestas con cabeceras de seguridad y caché controlada.

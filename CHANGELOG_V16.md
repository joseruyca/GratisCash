# GratisCash V16 · 1.14.0+16

## Adquisición medible
- Registra compartidos al copiar una oportunidad.
- Registra cargas de landing SEO sin almacenar IP, email, usuario ni fingerprint.
- Bots y crawlers conocidos no incrementan el contador de landings.
- Dashboard admin con compartidos, landings, salidas, conversiones e ingresos.
- Embudo aproximado por oportunidad para detectar qué contenido atrae y monetiza.

## SEO
- Corrige el rewrite /o/:id para pasar el ID real a la función SEO.
- Los enlaces copiados incluyen ?src=share para identificar su intención sin identificar al usuario.

## Seguridad
- Métricas agregadas en schema private.
- RPC públicas solo incrementan contadores de oportunidades existentes.
- La analítica nunca bloquea compartir, cargar una landing ni abrir una oportunidad.

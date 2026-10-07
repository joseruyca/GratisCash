# GratisCash V8

- Renombrado integral de la marca a GratisCash.
- Restauradas todas las pantallas del V7 original.
- Versión 1.6.0+8.
- Entornos staging / production; producción real exige datos legales completos.
- Build Flutter web reproducible para Vercel.
- Supabase real preparado con RLS, moderación, duplicados, apelaciones y Storage.
- Buckets seguros para avatares e imágenes de oportunidades.
- SECURITY DEFINER internos revocados como API pública cuando no son endpoints.
- Sin service_role ni claves secretas en el frontend.

- Hardening post-auditoría: perfiles, consentimiento legal, roles, RLS e índices.
- Caducidad automática horaria con Supabase Cron y trazabilidad de moderación.
- Borrado de cuenta v2: limpia Storage, revoca sesiones y elimina Auth.
- Registro usa señales booleanas; las fechas legales las escribe el servidor.
- Gestión de roles reservada a administradores y auditada.

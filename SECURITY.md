# Seguridad de Oportu V6

## Modelo de confianza
El cliente Flutter es no confiable. Cualquier persona puede inspeccionar/modificar el APK, IPA o JavaScript web; por tanto, las decisiones de seguridad se validan en PostgreSQL/RLS/RPC/Edge Functions.

## Claves
- Cliente: únicamente URL del proyecto y publishable key.
- Nunca `service_role` en Flutter, Git, web compilada, APK o IPA.
- `service_role` solo como secreto server-side para funciones que realmente lo necesitan.

## Autorización
- RLS activada en tablas privadas/UGC.
- Usuario normal no puede autoaprobar, verificar, destacar, editar afiliación, elevar rol ni modificar suspensión.
- Moderador/admin se valida en backend mediante `is_staff()`.
- Cambios de seguridad del perfil están protegidos también por trigger.

## Datos públicos
El público consume vistas con columnas limitadas. Campos internos de moderación, aceptación legal y suspensión no forman parte del perfil público.

## UGC
- Propuestas nacen `pending`.
- Consentimiento vigente obligatorio para proponer/comentar.
- Duplicado exacto protegido en DB además de la UI.
- Similitud aproximada sirve solo como señal.
- Motivos de rechazo y decisiones se auditan.
- Recurso de moderación disponible al autor.
- Denuncia y bloqueo disponibles.
- Comentarios de usuarios no aceptan enlaces.

## Antiabuso
- Límites de frecuencia en DB.
- Un reporte abierto por usuario/objeto.
- Índices/constraints para usernames y estados.
- Rate limits y bot protection de Supabase Auth deben configurarse también en el proyecto de producción.
- Administradores deben usar MFA en sus cuentas operativas.

## Eliminación de cuenta
La eliminación debe ejecutarse server-side. En V6, el UGC ligado a `author_id` se elimina en cascada con el perfil/cuenta; el contenido editorial creado sin autor permanece. Probar este comportamiento antes de producción.

## URLs
- Fuente, afiliación, imágenes y créditos externos: HTTPS.
- La UI valida antes de abrir enlaces.
- `source_url` y `affiliate_url` son campos diferentes.

## Archivos
Usuarios no suben imágenes en V6. Esto reduce malware, contenido ilegal, stripping de metadatos y superficie de moderación. Si se habilita en el futuro, requerirá bucket privado temporal, validación MIME/firma, límites, re-encode, moderación y políticas Storage separadas.

## Release gate
`tool/release_gate.ps1` bloquea release si:
- faltan valores reales de backend/legal;
- URL de producción no es HTTPS;
- aparecen marcadores prohibidos de runtime de demostración;
- `flutter analyze` o `flutter test` fallan.

## Pendiente antes de tiendas
- Pen-test/revisión independiente proporcional al riesgo.
- Probar RLS con anon/user/moderator/admin.
- Backups y restauración real.
- SMTP propio y Auth rate limits.
- Anti-bot/CAPTCHA cuando corresponda.
- Plan de incidentes y rotación de claves.
- Revisión de dependencias y advisories.
- App Links/Universal Links cerrados al dominio real.

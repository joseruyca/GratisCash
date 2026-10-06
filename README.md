# GRATISCASH PRO V6

GratisCash es una plataforma mobile-first de oportunidades verificables construida con Flutter para Android, iOS y web responsive, con Supabase como backend.

> Compatibilidad local: Dart 3.11 o superior y Flutter compatible. La restricción anterior de Dart 3.13 fue eliminada en V7.

## Estado V6

V7 mantiene la limpieza iniciada en V6 y elimina por completo el runtime de demostración. No existe `DemoRepository`, `demoMode`, perfiles ficticios ni actividad social simulada. Si el backend real no está configurado, GratisCash bloquea el arranque y muestra una pantalla de configuración segura en lugar de fingir que funciona.

La arquitectura está preparada para producción, pero **no debe publicarse todavía** hasta completar identidad legal, proyecto Supabase de producción, firma de tiendas y validación end-to-end descrita en `RELEASE_CHECKLIST.md`.

## Producto

- Feed: Destacados / Más votados / Subiendo / Nuevos / Terminan pronto.
- Categorías: Dinero, Producto gratis, Cashback, Bonus y Misión.
- Detalle con fuente oficial, condiciones, recompensa, caducidad, comentarios, votos, guardados, compartir y denuncias.
- Oportunidades expiradas permanecen visibles en el histórico pero sin CTA externo activo.
- Usuarios pueden proponer oportunidades; todas nacen `pending` y requieren moderación humana.
- Perfil con seguimiento de propuestas y motivo visible si una propuesta es rechazada.
- Recurso/revisión de moderación para el autor.
- Panel staff: pendientes, publicadas, denuncias, recursos y usuarios.
- `source_url` y `affiliate_url` separados; la afiliación solo la controla staff.

## Duplicados

GratisCash usa dos niveles:

1. **Bloqueo objetivo**: una URL normalizada idéntica que ya está activa o pendiente puede bloquear el nuevo envío.
2. **Señal de similitud**: título/fuente parecidos se muestran al usuario y a moderación, pero nunca provocan un rechazo automático por sí solos.

La decisión de similitud siempre es humana. Las acciones de moderación quedan auditadas.

## Seguridad

- Solo `SUPABASE_PUBLISHABLE_KEY` en el cliente.
- `service_role` exclusivamente server-side.
- RLS en datos privados y UGC.
- Roles, suspensión, afiliación, verificación y destacados protegidos en backend.
- Confirmación de email.
- Consentimiento versionado para publicar/comentar.
- Límites anti-spam en propuestas, comentarios y denuncias.
- Un reporte abierto por usuario/objeto.
- Bloqueo de usuarios.
- Comentarios sin enlaces para reducir phishing/spam.
- Eliminación de cuenta server-side.
- Auditoría de moderación y suspensión.
- Gate de release que impide builds de producción con backend o datos legales provisionales.

Ver `SECURITY.md` y `LEGAL_AND_MODERATION.md`.

## Backend

Para un proyecto Supabase nuevo ejecuta, en orden:

1. `supabase/migrations/001_gratiscash.sql`
2. `supabase/migrations/002_production_hardening.sql`
3. despliega `supabase/functions/delete-account`

Después configura Auth: confirmación de email, redirects/deep links cerrados, rate limits, protección anti-bot y SMTP de producción.

## Ejecutar con backend real

```powershell
cd "$env:USERPROFILE\Desktop\GRATISCASH"

& "C:\src\flutter\bin\flutter.bat" run -d chrome --web-port 8080 `
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_PUBLISHABLE_KEY `
  --dart-define=WEBSITE_URL=http://localhost:8080 `
  --dart-define=AUTH_REDIRECT_URL=http://localhost:8080/auth
```

Sin `SUPABASE_URL` y clave pública reales no se cargan datos falsos: aparece el bloqueo de configuración.

## Primera cuenta admin

Crea y confirma una cuenta normal. Después asigna el rol desde SQL Editor con el UUID real:

```sql
update public.profiles
set role = 'admin'
where id = 'UUID-DE-TU-USUARIO';
```

No existe una ruta pública para elevar privilegios.

## Release

No construyas para tiendas manualmente. Usa `tool/release_gate.ps1`, que exige backend, HTTPS e identidad legal reales y ejecuta análisis + tests antes de generar Android/web.

iOS debe construirse y firmarse en macOS/Xcode.

## Documentos

- `PRODUCT_SPEC.md`: alcance funcional.
- `SECURITY.md`: modelo de seguridad.
- `LEGAL_AND_MODERATION.md`: reglas operativas de moderación.
- `RELEASE_CHECKLIST.md`: requisitos antes de Play/App Store.
- `SOURCES_2026-10-02.md`: fuentes del catálogo inicial editorial.
- `CHANGELOG_V6.md`: cambios de esta versión.

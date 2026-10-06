# Oportu V6 · checklist de lanzamiento

## Legal e identidad
- [ ] `LEGAL_OWNER`, `LEGAL_EMAIL`, `LEGAL_ADDRESS` reales.
- [ ] Dominio y correo de soporte/legal definitivos.
- [ ] Política de privacidad, términos, aviso legal, comunidad y afiliación revisados con datos reales.
- [ ] Bases jurídicas, proveedores, transferencias y conservación definidos.
- [ ] Ruta pública + ruta in-app de eliminación de cuenta probadas.
- [ ] Apple App Privacy y Google Data Safety rellenados según comportamiento real.
- [ ] Consentimiento para tecnologías no necesarias si se añaden.

## Supabase / seguridad
- [ ] Proyectos dev y producción separados.
- [ ] Ejecutadas migraciones 001 + 002.
- [ ] RLS probada como anon, user, moderator y admin.
- [ ] Confirmación de email activada.
- [ ] SMTP propio de producción.
- [ ] Auth rate limits revisados.
- [ ] Protección anti-bot/CAPTCHA configurada si procede.
- [ ] Redirect URLs y deep links en allowlist cerrada.
- [ ] `delete-account` desplegada; `service_role` solo server-side.
- [ ] MFA en cuentas staff.
- [ ] Backups + restauración probada.
- [ ] Plan de incidentes y contacto de seguridad.

## Moderación / UGC
- [ ] Envío → duplicados → pending → aprobar/rechazar probado end-to-end.
- [ ] Rechazo exige motivo visible.
- [ ] Recurso del autor y respuesta de moderación probados.
- [ ] Duplicado exacto bloqueado en DB.
- [ ] Similitud aproximada nunca rechaza automáticamente.
- [ ] Denunciar oportunidad/comentario/usuario probado.
- [ ] Bloquear usuario probado.
- [ ] Suspender/restaurar usuario probado.
- [ ] Auditoría de decisiones revisada.
- [ ] Existe capacidad humana real para responder a denuncias y recursos.

## Contenido
- [ ] Revalidar cada oportunidad antes de lanzamiento.
- [ ] Condiciones, territorio, fechas/unidades y requisitos correctos.
- [ ] Fuente oficial guardada.
- [ ] Sin votos/comentarios/usuarios/ahorros inventados.
- [ ] Imágenes con licencia/derechos compatibles.
- [ ] Patrocinio/afiliación identificados cuando aplique.
- [ ] Caducadas conservan ficha pero CTA externo está desactivado.

## UX / accesibilidad
- [ ] Móvil pequeño/grande, tablet y desktop.
- [ ] Estados loading/empty/error/offline.
- [ ] Teclado web y lector de pantalla.
- [ ] Contraste y targets táctiles.
- [ ] Texto grande sin cortes críticos.
- [ ] Login/registro/confirmación/reenvío/recuperación con correos reales.

## Builds
- [ ] `flutter pub get`.
- [ ] `flutter analyze` limpio.
- [ ] `flutter test` verde.
- [ ] `flutter build appbundle --release` probado en Android real.
- [ ] `flutter build ipa --release` probado en iPhone real.
- [ ] `flutter build web --release` probado en Chrome/Safari/Firefox.
- [ ] Sin PWA/manifest instalable.
- [ ] Bundle IDs, firma, iconos, splash y store metadata definitivos.
- [ ] App Links/Universal Links verificados.

## Store review
- [ ] Cuenta de revisión preparada si la tienda necesita acceso autenticado.
- [ ] Contacto de moderación publicado.
- [ ] Funciones UGC de filtrar/denunciar/bloquear demostrables durante review.
- [ ] Eliminación de cuenta accesible dentro de app.

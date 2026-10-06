# GratisCash — especificación de producto V6

## Propuesta
Feed comunitario de oportunidades verificables: estudios remunerados, pruebas de producto, cashback, bonus y misiones. El catálogo inicial lo carga administración manualmente; la comunidad puede proponer nuevas oportunidades, pero nunca publicarlas directamente.

## Principios
- Mobile-first; Android/iOS son aplicaciones reales de tienda.
- Web responsive con el mismo backend; no PWA como sustituto de las apps.
- Lectura pública sin cuenta; cuenta solo para acciones comunitarias.
- Cero actividad social falsa.
- Todo UGC pasa por controles server-side.
- Caducadas permanecen como histórico.
- Fuente oficial y afiliación separadas.
- Una comisión nunca decide si una oportunidad es válida.

## Superficies
1. Inicio/feed
2. Explorar/buscar
3. Detalle
4. Terminadas/histórico
5. Guardadas
6. Publicar oportunidad
7. Novedades derivadas de datos reales
8. Login
9. Registro
10. Confirmación/reenvío de email
11. Recuperar/restablecer contraseña
12. Perfil/aportaciones
13. Editar perfil
14. Ajustes
15. Eliminar cuenta
16. Cómo funciona
17. Privacidad
18. Términos
19. Cookies/almacenamiento
20. Normas de comunidad
21. Afiliación/publicidad
22. Contacto/aviso legal
23. Moderación y recursos

### Staff
24. Pendientes
25. Publicadas
26. Crear oportunidad
27. Editar oportunidad
28. Denuncias
29. Recursos de moderación
30. Usuarios/suspensiones

## Estados
- `draft`: interno/futuro.
- `pending`: propuesta esperando revisión.
- `active`: pública y accionable.
- `expired`: pública como histórico, sin CTA de participación.
- `rejected`: visible al autor/staff con motivo y posibilidad de recurso.

Además, una fila `active` con `expires_at` vencido se presenta públicamente como terminada aunque aún no se haya archivado físicamente.

## Publicación comunitaria
- Requiere cuenta activa, email confirmado y consentimiento vigente de comunidad.
- La app comprueba duplicados antes de enviar.
- URL idéntica activa/pendiente: bloqueo objetivo.
- Similitud aproximada: advertencia, nunca rechazo automático.
- Usuario no puede establecer afiliación, portada, verificación, destacado ni estado público.
- La moderación registra motivo de rechazo.
- El autor puede solicitar revisión.

## Moderación
- Aprobar.
- Rechazar con motivo obligatorio.
- Marcar duplicado enlazando al contenido existente.
- Archivar.
- Revisar denuncias.
- Suspender/restaurar usuarios con motivo.
- Resolver recursos con respuesta visible para el autor.
- Registrar acciones relevantes en auditoría.

## Contenido y comentarios
- Comentarios requieren consentimiento vigente.
- Enlaces en comentarios bloqueados para reducir phishing/spam.
- Denunciar oportunidad, comentario o usuario.
- Bloquear usuario.
- Contenido retirado no cuenta en métricas públicas.

## Imágenes
- Usuarios no suben archivos en V6.
- Staff controla `image_url`, crédito y fuente.
- Antes de lanzamiento: usar imágenes propias/autorizadas/licenciadas y conservar evidencia de licencia cuando aplique.

## Autenticación
- Email/contraseña.
- Confirmación de email.
- Contraseña de registro: mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.
- Recuperación mediante flujo de Supabase.
- PKCE.
- Consentimiento versionado de términos/comunidad.
- Confirmación 18+ para crear UGC en esta versión.
- Eliminación de cuenta dentro del producto y ruta web pública.

## Producción
No existe modo demo. Si faltan backend o datos legales de release, la app/build se bloquea en lugar de simular datos.

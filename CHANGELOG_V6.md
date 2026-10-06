# GratisCash PRO V6 — producción, moderación y seguridad

- Eliminado todo runtime de demostración: sin `DemoRepository`, `demoMode`, usuarios ficticios ni acciones simuladas.
- Sin backend real, la app no inventa contenido: muestra un bloqueo explícito de configuración.
- Login/registro reforzado con email verificado, PKCE, contraseña fuerte, mayoría de edad y aceptación versionada.
- Consentimiento de comunidad renovable cuando cambian sustancialmente las reglas.
- Duplicados en dos capas: URL normalizada + similitud semántica; las páginas genéricas reutilizadas no se bloquean solo por compartir URL.
- Duplicado exacto protegido también en DB para evitar carreras entre clientes.
- La similitud aproximada nunca rechaza automáticamente.
- Cola de moderación con motivo obligatorio al rechazar y acción específica para duplicados.
- Recursos de moderación para autores y respuesta trazable.
- Auditoría de aprobaciones, rechazos, duplicados, archivos y recursos.
- Gestión staff de denuncias y suspensión/restauración de usuarios con motivo.
- Una denuncia abierta por persona/objeto para reducir abuso.
- Enlaces bloqueados en comentarios UGC para reducir phishing/spam.
- Eliminación de cuenta endurecida con borrado en cascada del UGC ligado al autor.
- Vistas públicas reducidas; datos internos permanecen en tablas protegidas.
- Release gate impide builds de producción con backend/legal incompletos o runtime de demo.
- Documentación de lanzamiento, seguridad y moderación actualizada.
- Versión 1.4.0+6.

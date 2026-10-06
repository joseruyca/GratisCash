# OPORTU V7 — endurecimiento y pulido de producto

- Compatibilidad corregida con Dart 3.11.x (`sdk >=3.11.0`), evitando el bloqueo de dependencias detectado en el equipo local.
- Versión actualizada a `1.5.0+7`.
- Búsqueda endurecida: sanitización de caracteres reservados, límite de longitud y búsqueda con debounce de 350 ms.
- Pantalla Explorar más fluida: el botón de limpiar aparece mientras se escribe y la búsqueda se actualiza sin exigir Enter.
- Guardadas ya no dependen del límite de 100 oportunidades generales: se consultan directamente los IDs guardados y sus oportunidades.
- Mensajes de error de producción centralizados y comprensibles; se evita mostrar excepciones internas/Supabase al usuario.
- Ruta 404 propia para enlaces rotos o deep links inválidos.
- Apertura de URLs externas endurecida: solo HTTPS válido y sin credenciales embebidas.
- Ajustes visuales de tema: superficies, navegación inferior y radios más consistentes.
- `ARRANCAR.ps1` y `release_gate.ps1` ya buscan Flutter en el PATH antes de usar `C:\src\flutter`, reduciendo fallos por instalación.
- Se mantiene V6 sin runtime demo, con moderación, duplicados, consentimiento y release gate.

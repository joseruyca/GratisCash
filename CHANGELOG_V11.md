# GratisCash V11 · 1.9.0+11

## Valoración comunitaria
- Sustituye el voto único positivo por 👍 / 👎.
- Puntuación pública neta = positivos − negativos.
- Pulsar el mismo voto de nuevo lo elimina.
- Cambiar de 👍 a 👎 sustituye el voto anterior; nunca crea votos duplicados.
- El autor no puede valorar su propia oportunidad.
- Solo las oportunidades activas y no caducadas aceptan votos.
- Inicio y Explorar recuerdan el voto del usuario y resaltan el pulgar seleccionado.
- "Más votados" y "Subiendo" utilizan la puntuación neta.

## Privacidad y seguridad
- La API pública solo recibe contadores agregados.
- La identidad de los votantes no se expone.
- RLS permite a cada usuario leer únicamente sus propias filas de voto.
- El cliente pierde permisos directos de INSERT/UPDATE/DELETE sobre votos.
- Toda modificación de voto pasa por RPC validada en servidor.

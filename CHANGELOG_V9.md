# GratisCash V9 · 1.7.0+9

## Producto
- Publicación de oportunidades con imagen opcional desde web, Android e iOS.
- Avatar real de usuario con sustitución de la foto anterior.
- Tarjetas móviles más compactas y estados de moderación sin acciones engañosas.
- Cabecera de Inicio simplificada en pantallas estrechas.
- Transparencia de afiliación en la ficha y acceso separado a la fuente oficial.

## Seguridad
- Las imágenes de usuario se asocian mediante rutas de Supabase Storage verificadas en servidor.
- Una cuenta solo puede asociar una imagen a su propia propuesta pendiente.
- El avatar solo puede apuntar al objeto `<uid>/avatar` propiedad del usuario.
- No se aceptan URLs de imagen arbitrarias como parte de una propuesta de comunidad.
- Se conservan los límites de tamaño/MIME definidos en Storage y en el cliente.

## Plataformas
- image_picker compatible con el stack actual.
- Android generado con minSdk 24+.
- iOS preparado para 13+ y con descripción de uso de fototeca.
- Web mantiene el mismo flujo sin convertirse en PWA instalable.

## Pendiente antes de producción pública
- Datos legales reales del titular.
- URLs definitivas de Supabase Auth.
- Validación `flutter analyze/test/build` en entorno Flutter y `pubspec.lock` commiteado.
- Dejar conectado a GitHub únicamente el proyecto Vercel definitivo.

- El release gate fuerza `APP_ENV=production`; una build pública no puede quedar accidentalmente en staging.

- Flutter 3.41.6 fijado en Vercel y en el release gate para builds reproducibles.

- Storage solo acepta una imagen vinculada a una propuesta pendiente propia (`uid/opportunity/image.ext`), evitando usar el bucket como alojamiento arbitrario.

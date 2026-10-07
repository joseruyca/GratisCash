import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final data = _content(kind);
    return Scaffold(
      appBar: AppBar(title: Text(data.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 70),
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Versión de términos/comunidad: ${AppConfig.termsVersion}',
                style: const TextStyle(
                  color: GratisCashTheme.muted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 18),
              for (final section in data.sections) ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      for (final paragraph in section.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            paragraph,
                            style: const TextStyle(fontSize: 15, height: 1.52),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _LegalContent _content(String value) {
    switch (value) {
      case 'how':
        return const _LegalContent('Cómo funciona GratisCash', [
          _LegalSection('Qué encontrarás', [
            'GratisCash reúne oportunidades para ganar recompensas, probar productos, conseguir reembolsos, aprovechar bonus y encontrar misiones remuneradas. Salvo indicación expresa, GratisCash no es la empresa que ofrece cada promoción.',
          ]),
          _LegalSection('Cómo verificamos', [
            'Cada ficha muestra la fuente original y las condiciones importantes. Las publicaciones directas de GratisCash se revisan antes de aparecer y las propuestas de la comunidad permanecen pendientes hasta que un moderador las comprueba.',
          ]),
          _LegalSection('Qué ocurre cuando termina', [
            'Las oportunidades finalizadas no se borran del histórico editorial: pasan a estado inactivo y quedan claramente marcadas como terminadas. El contenido personal de una cuenta eliminada se trata según la Política de privacidad y la lógica de eliminación de cuenta.',
          ]),
          _LegalSection('Comunidad', [
            'Los votos, guardados y comentarios ayudan a ordenar y enriquecer el contenido, pero no sustituyen la verificación. Si detectas información falsa, una promoción terminada o cualquier problema, puedes denunciarla desde su ficha.',
          ]),
          _LegalSection('Monetización', [
            'Algunos enlaces pueden generar una comisión para GratisCash. El contenido patrocinado deberá identificarse claramente y la monetización no elimina la obligación de mostrar la fuente y las condiciones relevantes.',
          ]),
        ]);
      case 'privacy':
        return _LegalContent('Política de privacidad', [
          _LegalSection('Responsable', [
            'Titular: ${AppConfig.legalOwner}. Contacto: ${AppConfig.legalEmail}. Domicilio: ${AppConfig.legalAddress}. Estos campos deben contener la información jurídica real antes del lanzamiento público.',
          ]),
          const _LegalSection('Qué datos utiliza GratisCash', [
            'Cuenta y perfil: identificador, email gestionado por Supabase Auth, nombre mostrado, usuario público, aceptación de términos y confirmación de mayoría de edad. Comunidad: oportunidades propuestas, comentarios, votos, guardados, bloqueos, denuncias y solicitudes de revisión. Seguridad: registros técnicos proporcionados por la infraestructura para prevenir abuso, investigar incidencias y proteger cuentas.',
            'GratisCash no necesita contactos, micrófono, agenda ni geolocalización precisa para las funciones descritas en esta versión. Si en el futuro se solicita un permiso nuevo, deberá justificarse y documentarse antes de activarlo.',
          ]),
          const _LegalSection('Finalidades y conservación', [
            'Los datos se usan para prestar la cuenta y las funciones solicitadas, moderar contenido generado por usuarios, prevenir fraude y abuso, resolver recursos y proteger el servicio. Antes del lanzamiento deben fijarse en la política legal definitiva los periodos de conservación de registros de seguridad, moderación y obligaciones legales.',
          ]),
          const _LegalSection('Eliminación de cuenta', [
            'Al eliminar una cuenta se elimina la cuenta de autenticación y el contenido generado por esa persona que permanezca asociado a ella, incluidos comentarios y oportunidades de usuario, salvo que exista una obligación legal concreta que exija conservar un dato determinado. Los datos que deban conservarse por una obligación específica deben limitarse a lo necesario y documentarse.',
          ]),
          const _LegalSection('Terceros y enlaces externos', [
            'Las oportunidades enlazan a webs de terceros. Sus formularios y tratamientos pertenecen a esos terceros. GratisCash no controla la privacidad de las páginas externas. Los proveedores técnicos, encargados de tratamiento y eventuales transferencias internacionales deberán constar en la política definitiva.',
          ]),
          _LegalSection('Tus derechos', [
            'Puedes ejercer los derechos que resulten aplicables mediante ${AppConfig.legalEmail}. La eliminación de cuenta está disponible dentro de GratisCash y mediante la web en ${AppConfig.websiteUrl}/account/delete. También podrás acudir a la autoridad de control competente cuando corresponda.',
          ]),
        ]);
      case 'cookies':
        return const _LegalContent('Cookies y almacenamiento web', [
          _LegalSection('Versión actual', [
            'GratisCash no incorpora analítica publicitaria ni publicidad comportamental en esta versión. La web puede utilizar almacenamiento técnico estrictamente necesario para autenticación, seguridad y preferencias de funcionamiento.',
          ]),
          _LegalSection('Si esto cambia', [
            'Si se añaden tecnologías no necesarias, deberán permanecer desactivadas hasta obtener el consentimiento válido cuando la normativa aplicable lo exija, ofreciendo una opción de rechazo equivalente y un mecanismo posterior para cambiar la elección.',
          ]),
        ]);
      case 'terms':
        return _LegalContent('Términos de uso', [
          const _LegalSection('Qué es GratisCash', [
            'GratisCash es una plataforma de descubrimiento y comunidad. Salvo indicación expresa, no es la empresa que ofrece la campaña, producto, estudio o promoción enlazados.',
          ]),
          _LegalSection('Edad y cuenta', [
            'Para crear una cuenta y participar en la comunidad debes confirmar que tienes al menos ${AppConfig.minimumAccountAge} años y aceptar la versión vigente de estos términos y de las normas de comunidad. Algunas oportunidades de terceros pueden imponer requisitos de edad adicionales.',
          ]),
          const _LegalSection('Información de oportunidades', [
            'Las condiciones pueden cambiar, agotarse o finalizar anticipadamente. Comprueba siempre la fuente oficial antes de comprar, registrarte o compartir datos con un tercero. GratisCash puede corregir, archivar o retirar contenido cuando sea necesario.',
          ]),
          const _LegalSection('Contenido de usuarios', [
            'Está prohibido publicar contenido ilegal, fraudulento, acosador, discriminatorio, que infrinja derechos de terceros, contenga datos personales ajenos sin base legítima, spam o enlaces maliciosos. Las propuestas de usuarios requieren moderación antes de hacerse públicas.',
          ]),
          const _LegalSection('Duplicados y manipulación', [
            'No se permite publicar deliberadamente la misma oportunidad varias veces para ganar visibilidad. El sistema puede bloquear coincidencias exactas y señalar similitudes para revisión humana. Una similitud aproximada no produce por sí sola una sanción automática.',
          ]),
          const _LegalSection('Histórico', [
            'Las oportunidades editoriales o de comunidad que finalizan pueden permanecer visibles como histórico claramente inactivo. La eliminación de una cuenta aplica además la política de eliminación de datos asociados a esa persona.',
          ]),
        ]);
      case 'community':
        return const _LegalContent('Normas de la comunidad', [
          _LegalSection('Publica de buena fe', [
            'Enlaza a una fuente oficial o razonablemente verificable, describe lo que sabes sin inventar condiciones y evita duplicados deliberados. No publiques una oportunidad solo para redirigir tráfico hacia una página que no sea la fuente real.',
          ]),
          _LegalSection('No permitido', [
            'Estafas, esquemas piramidales, enlaces maliciosos, amenazas, acoso, odio, contenido ilegal, spam, suplantación, manipulación coordinada de votos y publicación de datos personales de terceros.',
          ]),
          _LegalSection('Denunciar y bloquear', [
            'Puedes denunciar oportunidades, comentarios o usuarios cuando incumplan estas normas. También puedes bloquear a otros usuarios. Las denuncias deben usarse de buena fe y no como herramienta de acoso.',
          ]),
          _LegalSection('Moderación', [
            'GratisCash puede revisar, rechazar, archivar o retirar contenido y limitar cuentas cuando sea necesario para la seguridad, el cumplimiento o la integridad de la comunidad. Las decisiones negativas sobre una oportunidad deben incluir un motivo comprensible y, cuando corresponda, pueden solicitarse para revisión.',
          ]),
        ]);
      case 'moderation':
        return const _LegalContent('Moderación y revisiones', [
          _LegalSection('Antes de publicar', [
            'Las oportunidades propuestas por usuarios entran en una cola pendiente. El equipo puede comprobar la fuente, la vigencia, la categoría, el beneficio, posibles duplicados y señales de fraude o spam antes de decidir.',
          ]),
          _LegalSection('Duplicados', [
            'Una URL activa idéntica puede bloquearse automáticamente para impedir duplicados exactos. Las coincidencias aproximadas de título o fuente solo generan una señal para moderación: no provocan por sí mismas un rechazo automático.',
          ]),
          _LegalSection('Decisiones motivadas', [
            'Si una oportunidad se rechaza, la decisión debe registrar un motivo. Si se marca como duplicada, debe poder vincularse con la oportunidad existente. Las acciones de moderación relevantes quedan registradas para trazabilidad interna.',
          ]),
          _LegalSection('Solicitar revisión', [
            'El autor de una oportunidad rechazada puede enviar una solicitud de revisión explicando por qué considera que la decisión debería reconsiderarse. El equipo puede reabrir la publicación, confirmar la decisión o descartar la revisión, dejando una respuesta.',
          ]),
          _LegalSection('Cuentas y seguridad', [
            'El contenido ilegal, el fraude, el spam, el acoso y los intentos de evadir sanciones pueden dar lugar a retirada de contenido o limitación de cuenta. Las medidas deben ser proporcionadas al riesgo y documentarse cuando proceda. Una cuenta limitada verá el motivo registrado y podrá usar el canal de contacto para solicitar una revisión adicional.',
          ]),
        ]);
      case 'affiliate':
        return const _LegalContent('Afiliación y publicidad', [
          _LegalSection('Afiliación', [
            'Algunos enlaces de salida pueden ser de afiliación. Si una acción válida genera comisión, GratisCash puede recibir una remuneración sin que ello suponga un coste adicional para el usuario. La fuente oficial y el enlace monetizado se mantienen separados.',
          ]),
          _LegalSection('Contenido patrocinado', [
            'Una marca puede financiar la presencia de una oportunidad únicamente cuando exista una promoción real y útil. Esa ficha se identifica de forma visible como “Patrocinada” e indica el nombre del patrocinador mientras la campaña está activa.',
          ]),
          _LegalSection('Destacada no significa pagada', [
            'La etiqueta “Destacada” responde a una decisión editorial de GratisCash. Pagar una campaña no concede por sí mismo esa etiqueta, votos, comentarios, posiciones de popularidad ni una valoración más favorable.',
          ]),
          _LegalSection('Independencia y transparencia', [
            'La existencia de afiliación o patrocinio no elimina los requisitos de moderación, fuente, condiciones ni seguridad. GratisCash no debe ocultar la naturaleza comercial de una campaña.',
          ]),
        ]);
      case 'contact':
        return _LegalContent('Contacto y aviso legal', [
          _LegalSection('Contacto', [
            'Soporte, moderación y avisos: ${AppConfig.legalEmail}. Para una incidencia concreta también puedes utilizar “Denunciar” dentro de la oportunidad o comentario.',
          ]),
          _LegalSection('Titular del servicio', [
            '${AppConfig.legalOwner}. Domicilio: ${AppConfig.legalAddress}. Estos campos son marcadores técnicos y deben contener datos legales reales antes de hacer pública la plataforma.',
          ]),
          const _LegalSection('Antes del lanzamiento', [
            'Esta pantalla forma parte de la arquitectura del producto, pero no sustituye una revisión jurídica del texto definitivo, de la identidad del titular, fiscalidad, bases legales aplicables a promociones propias ni contratos con proveedores.',
          ]),
        ]);
      default:
        return const _LegalContent('Información', [
          _LegalSection('GratisCash', ['Información de GratisCash.']),
        ]);
    }
  }
}

class _LegalContent {
  const _LegalContent(this.title, this.sections);
  final String title;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

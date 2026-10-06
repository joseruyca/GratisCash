import 'package:flutter_test/flutter_test.dart';
import 'package:oportu/data/models.dart';

Opportunity _opportunity({
  OpportunityStatus status = OpportunityStatus.active,
  DateTime? expiresAt,
  String? affiliateUrl,
}) {
  return Opportunity(
    id: 'test',
    title: 'Oportunidad de prueba',
    description: 'Descripción suficiente para probar el modelo.',
    sourceName: 'Fuente',
    sourceUrl: 'https://example.com/source',
    affiliateUrl: affiliateUrl,
    rewardText: '10 €',
    category: OpportunityCategory.money,
    status: status,
    createdAt: DateTime(2026, 10, 2),
    expiresAt: expiresAt,
  );
}

void main() {
  test('una oportunidad vencida se considera terminada aunque siga active', () {
    final item = _opportunity(
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(item.isExpired, isTrue);
  });

  test('una oportunidad futura sigue activa', () {
    final item = _opportunity(
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    expect(item.isExpired, isFalse);
  });

  test('el enlace afiliado tiene prioridad sin perder la fuente oficial', () {
    final item = _opportunity(affiliateUrl: 'https://example.com/affiliate');

    expect(item.sourceUrl, 'https://example.com/source');
    expect(item.outboundUrl, 'https://example.com/affiliate');
  });

  test('sin afiliación se usa la fuente oficial', () {
    final item = _opportunity();

    expect(item.outboundUrl, item.sourceUrl);
  });

  test('la urgencia se calcula solo para oportunidades próximas', () {
    final tomorrow = _opportunity(
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
    final later = _opportunity(
      expiresAt: DateTime.now().add(const Duration(days: 10)),
    );

    expect(tomorrow.endsSoon, isTrue);
    expect(tomorrow.urgencyLabel, isNotNull);
    expect(later.endsSoon, isFalse);
    expect(later.urgencyLabel, isNull);
  });

  test('las categorías públicas tienen etiquetas en español', () {
    expect(OpportunityCategory.money.label, 'Dinero');
    expect(OpportunityCategory.freeProduct.label, 'Producto gratis');
    expect(OpportunityCategory.cashback.label, 'Cashback');
    expect(OpportunityCategory.bonus.label, 'Bonus');
    expect(OpportunityCategory.mission.label, 'Misión');
  });
}

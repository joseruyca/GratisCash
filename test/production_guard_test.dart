import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el runtime de producción no contiene repositorio ni modo demo', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final forbidden = <String>[
      'DemoRepository',
      'demoMode',
      'Usuario demo',
      '@modo_demo',
      'demo_data.dart',
    ];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final token in forbidden) {
        expect(
          content.contains(token),
          isFalse,
          reason: '${entity.path} contiene el marcador de desarrollo $token',
        );
      }
    }
  });

  test('la migración de producción incluye duplicados, apelaciones y auditoría', () {
    final file = File('supabase/migrations/002_production_hardening.sql');
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();

    expect(sql.contains('find_duplicate_opportunities'), isTrue);
    expect(sql.contains('moderation_appeals'), isTrue);
    expect(sql.contains('moderation_actions'), isTrue);
    expect(sql.contains('has_current_community_consent'), isTrue);
    expect(sql.contains('reports_one_open_per_target_idx'), isTrue);
    expect(sql.contains('opportunities_author_id_fkey'), isTrue);
    expect(sql.contains('on delete cascade'), isTrue);
  });
}

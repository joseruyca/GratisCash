import 'package:flutter_test/flutter_test.dart';
import 'package:gratiscash/core/config.dart';
import 'package:gratiscash/data/models.dart';

void main() {
  test('el consentimiento de comunidad exige versión vigente y mayoría de edad', () {
    final now = DateTime.now();
    final valid = UserProfile(
      id: '1',
      username: 'usuario',
      displayName: 'Usuario',
      role: 'user',
      createdAt: now,
      termsVersion: AppConfig.termsVersion,
      termsAcceptedAt: now,
      adultConfirmedAt: now,
    );
    final outdated = UserProfile(
      id: '2',
      username: 'usuario2',
      displayName: 'Usuario',
      role: 'user',
      createdAt: now,
      termsVersion: 'anterior',
      termsAcceptedAt: now,
      adultConfirmedAt: now,
    );

    expect(valid.hasCurrentCommunityConsent, isTrue);
    expect(outdated.hasCurrentCommunityConsent, isFalse);
  });

  test('una coincidencia exacta siempre es fuerte', () {
    const candidate = DuplicateCandidate(
      id: 'x',
      title: 'Prueba',
      sourceName: 'Fuente',
      status: 'active',
      score: 0.1,
      exactUrl: true,
    );
    expect(candidate.isStrongMatch, isTrue);
  });
}

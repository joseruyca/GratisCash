import 'package:flutter_test/flutter_test.dart';
import 'package:gratiscash/data/models.dart';

void main() {
  test('Opportunity parses bidirectional vote aggregates', () {
    final item = Opportunity.fromMap({
      'id': '00000000-0000-0000-0000-000000000001',
      'title': 'Test',
      'description': 'Description',
      'source_name': 'Source',
      'source_url': 'https://example.org',
      'reward_text': 'Gratis',
      'category': 'freeProduct',
      'status': 'active',
      'created_at': '2026-10-07T00:00:00Z',
      'upvote_count': 12,
      'downvote_count': 4,
      'vote_score': 8,
      'comment_count': 2,
    });

    expect(item.upvotes, 12);
    expect(item.downvotes, 4);
    expect(item.voteScore, 8);

    final updated = item.copyWith(
      upvotes: 13,
      downvotes: 5,
      voteScore: 8,
    );
    expect(updated.upvotes, 13);
    expect(updated.downvotes, 5);
    expect(updated.voteScore, 8);
  });
}

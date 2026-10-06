import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import 'models.dart';

abstract class GratisCashRepository {
  Future<List<Opportunity>> listOpportunities({
    bool includeExpired = false,
    OpportunityCategory? category,
    String? query,
  });

  Future<Opportunity?> getOpportunity(String id);
  Future<List<AppComment>> comments(String opportunityId);
  Future<void> addComment(String opportunityId, String body);
  Future<void> toggleVote(String opportunityId);
  Future<void> toggleSaved(String opportunityId);
  Future<Set<String>> savedIds();
  Future<List<Opportunity>> savedOpportunities();
  Future<UserProfile?> currentProfile();
  Future<void> updateMyProfile({
    required String displayName,
    required String username,
  });
  Future<void> acceptCommunityTerms();
  Future<List<Opportunity>> mySubmissions();
  Future<bool> isStaff();
  Future<List<DuplicateCandidate>> findDuplicates({
    required String sourceUrl,
    required String title,
    required String sourceName,
  });
  Future<void> submitOpportunity(Map<String, dynamic> draft);
  Future<void> appealModeration(String opportunityId, String message);
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String reasonCode = 'other',
  });
  Future<void> blockUser(String userId);
  Future<List<Map<String, dynamic>>> pendingForAdmin();
  Future<List<Opportunity>> adminPublished();
  Future<List<Map<String, dynamic>>> reportsForAdmin();
  Future<List<Map<String, dynamic>>> usersForAdmin();
  Future<List<ModerationAppeal>> appealsForAdmin();
  Future<void> moderate(
    String id,
    String status, {
    String? reason,
    String? duplicateOf,
  });
  Future<void> reviewReport(String id, String status);
  Future<void> setUserSuspended({
    required String id,
    required bool suspended,
    required String reason,
  });
  Future<void> resolveAppeal({
    required String id,
    required String decision,
    required String response,
  });
  Future<void> adminCreateOpportunity(Map<String, dynamic> data);
  Future<void> adminUpdateOpportunity(String id, Map<String, dynamic> data);
  Future<void> deleteMyAccount();
}

class SupabaseRepository implements GratisCashRepository {
  SupabaseClient get db => Supabase.instance.client;

  String get _uid {
    final id = db.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Debes iniciar sesión.');
    }
    return id;
  }

  @override
  Future<List<Opportunity>> listOpportunities({
    bool includeExpired = false,
    OpportunityCategory? category,
    String? query,
  }) async {
    dynamic request = db.from('opportunities_public').select();

    if (!includeExpired) {
      request = request.eq('effective_status', 'active');
    }
    if (category != null) {
      request = request.eq('category', category.name);
    }

    final normalizedQuery = (query?.trim() ?? '').replaceAll(
      RegExp(r'[,().:%*]'),
      ' ',
    );
    final safeQuery = normalizedQuery.length > 80
        ? normalizedQuery.substring(0, 80)
        : normalizedQuery;
    if (safeQuery.isNotEmpty) {
      request = request.or(
        'title.ilike.%$safeQuery%,source_name.ilike.%$safeQuery%,description.ilike.%$safeQuery%',
      );
    }

    final rows = await request
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map(
          (row) => Opportunity.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<Opportunity?> getOpportunity(String id) async {
    final row = await db
        .from('opportunities_public')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return Opportunity.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<AppComment>> comments(String opportunityId) async {
    final rows = await db
        .from('comments_public')
        .select()
        .eq('opportunity_id', opportunityId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map(
          (row) => AppComment.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> addComment(String opportunityId, String body) async {
    final text = body.trim();
    if (text.length < 2 || text.length > 1200) {
      throw ArgumentError('El comentario debe tener entre 2 y 1200 caracteres.');
    }
    await db.from('comments').insert({
      'opportunity_id': opportunityId,
      'author_id': _uid,
      'body': text,
    });
  }

  @override
  Future<void> toggleVote(String opportunityId) async {
    await db.rpc(
      'toggle_opportunity_vote',
      params: {'p_opportunity_id': opportunityId},
    );
  }

  @override
  Future<void> toggleSaved(String opportunityId) async {
    await db.rpc(
      'toggle_saved_opportunity',
      params: {'p_opportunity_id': opportunityId},
    );
  }

  @override
  Future<Set<String>> savedIds() async {
    if (db.auth.currentUser == null) {
      return <String>{};
    }
    final rows = await db.from('saved_opportunities').select('opportunity_id');
    return (rows as List<dynamic>)
        .map((row) => (row as Map)['opportunity_id'].toString())
        .toSet();
  }

  @override
  Future<List<Opportunity>> savedOpportunities() async {
    if (db.auth.currentUser == null) {
      return <Opportunity>[];
    }
    final ids = await savedIds();
    if (ids.isEmpty) return <Opportunity>[];

    final rows = await db
        .from('opportunities_public')
        .select()
        .inFilter('id', ids.toList())
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map(
          (row) => Opportunity.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<UserProfile?> currentProfile() async {
    if (db.auth.currentUser == null) {
      return null;
    }
    final row = await db.from('profiles').select().eq('id', _uid).maybeSingle();
    if (row == null) {
      return null;
    }
    return UserProfile.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> updateMyProfile({
    required String displayName,
    required String username,
  }) async {
    final name = displayName.trim();
    final handle = username.trim().toLowerCase();
    const reserved = <String>{
      'gratiscash',
      'gratiscashapp',
      'admin',
      'administrator',
      'moderator',
      'moderador',
      'support',
      'soporte',
      'staff',
      'official',
      'oficial',
    };
    if (name.length < 2 || name.length > 60) {
      throw ArgumentError('Nombre visible no válido.');
    }
    if (!RegExp(r'^[a-z0-9_.]{3,32}$').hasMatch(handle) ||
        reserved.contains(handle)) {
      throw ArgumentError('Ese nombre de usuario no está disponible.');
    }
    await db.from('profiles').update({
      'display_name': name,
      'username': handle,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', _uid);
  }

  @override
  Future<void> acceptCommunityTerms() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.from('profiles').update({
      'terms_version': AppConfig.termsVersion,
      'terms_accepted_at': now,
      'adult_confirmed_at': now,
      'updated_at': now,
    }).eq('id', _uid);
  }

  @override
  Future<List<Opportunity>> mySubmissions() async {
    if (db.auth.currentUser == null) {
      return <Opportunity>[];
    }
    final rows = await db
        .from('opportunities')
        .select()
        .eq('author_id', _uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map(
          (row) => Opportunity.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<bool> isStaff() async {
    final profile = await currentProfile();
    return profile?.isStaff ?? false;
  }

  @override
  Future<List<DuplicateCandidate>> findDuplicates({
    required String sourceUrl,
    required String title,
    required String sourceName,
  }) async {
    final rows = await db.rpc(
      'find_duplicate_opportunities',
      params: {
        'p_source_url': sourceUrl.trim(),
        'p_title': title.trim(),
        'p_source_name': sourceName.trim(),
      },
    );
    return (rows as List<dynamic>)
        .map(
          (row) => DuplicateCandidate.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> submitOpportunity(Map<String, dynamic> draft) async {
    await db.from('opportunities').insert({
      ...draft,
      'author_id': _uid,
      'status': 'pending',
      'is_verified': false,
      'affiliate_url': null,
      'is_featured': false,
      'photo_credit': null,
      'photo_source_url': null,
      'moderation_reason': null,
      'duplicate_of': null,
    });
  }

  @override
  Future<void> appealModeration(String opportunityId, String message) async {
    final text = message.trim();
    if (text.length < 10 || text.length > 1200) {
      throw ArgumentError('Explica el motivo de la revisión en 10–1200 caracteres.');
    }
    await db.from('moderation_appeals').insert({
      'opportunity_id': opportunityId,
      'author_id': _uid,
      'message': text,
    });
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String reasonCode = 'other',
  }) async {
    final text = reason.trim();
    if (text.length < 2 || text.length > 500) {
      throw ArgumentError('Motivo de denuncia no válido.');
    }
    await db.from('reports').insert({
      'reporter_id': _uid,
      'target_type': targetType,
      'target_id': targetId,
      'reason': text,
      'reason_code': reasonCode,
    });
  }

  @override
  Future<void> blockUser(String userId) async {
    await db.from('blocked_users').upsert({
      'blocker_id': _uid,
      'blocked_id': userId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> pendingForAdmin() async {
    final rows = await db
        .from('opportunities_admin')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  @override
  Future<List<Opportunity>> adminPublished() async {
    final rows = await db
        .from('opportunities_admin')
        .select()
        .inFilter('status', ['active', 'expired'])
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List<dynamic>)
        .map(
          (row) => Opportunity.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> reportsForAdmin() async {
    final rows = await db
        .from('reports_admin')
        .select()
        .inFilter('status', ['open', 'reviewing'])
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> usersForAdmin() async {
    final rows = await db
        .from('profiles_admin')
        .select()
        .order('is_suspended', ascending: false)
        .order('open_report_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  @override
  Future<List<ModerationAppeal>> appealsForAdmin() async {
    final rows = await db
        .from('moderation_appeals_admin')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map(
          (row) => ModerationAppeal.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> moderate(
    String id,
    String status, {
    String? reason,
    String? duplicateOf,
  }) async {
    await db.rpc(
      'moderate_opportunity',
      params: {
        'p_id': id,
        'p_status': status,
        'p_reason': reason,
        'p_duplicate_of': duplicateOf,
      },
    );
  }

  @override
  Future<void> reviewReport(String id, String status) async {
    await db.from('reports').update({
      'status': status,
      'reviewer_id': _uid,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> setUserSuspended({
    required String id,
    required bool suspended,
    required String reason,
  }) async {
    final text = reason.trim();
    if (text.length < 8 || text.length > 2000) {
      throw ArgumentError('El motivo debe tener entre 8 y 2000 caracteres.');
    }
    await db.rpc(
      'set_user_suspension',
      params: {
        'p_user_id': id,
        'p_suspended': suspended,
        'p_reason': text,
      },
    );
  }

  @override
  Future<void> resolveAppeal({
    required String id,
    required String decision,
    required String response,
  }) async {
    await db.rpc(
      'resolve_moderation_appeal',
      params: {
        'p_id': id,
        'p_decision': decision,
        'p_response': response.trim(),
      },
    );
  }

  @override
  Future<void> adminCreateOpportunity(Map<String, dynamic> data) async {
    await db.from('opportunities').insert({
      ...data,
      'status': 'active',
      'is_verified': true,
      'moderator_id': _uid,
      'moderated_at': DateTime.now().toUtc().toIso8601String(),
      'published_at': DateTime.now().toUtc().toIso8601String(),
      'last_verified_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> adminUpdateOpportunity(
    String id,
    Map<String, dynamic> data,
  ) async {
    await db.from('opportunities').update({
      ...data,
      'moderator_id': _uid,
      'moderated_at': DateTime.now().toUtc().toIso8601String(),
      'last_verified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> deleteMyAccount() async {
    final response = await db.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw StateError('No se pudo eliminar la cuenta.');
    }
    await db.auth.signOut();
  }
}

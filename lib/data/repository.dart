import 'dart:typed_data';

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
  Future<int> setVote(String opportunityId, int value);
  Future<Map<String, int>> voteStates(Iterable<String> opportunityIds);
  Future<void> toggleSaved(String opportunityId);
  Future<void> registerOutboundClick(String opportunityId);
  Future<Set<String>> savedIds();
  Future<List<Opportunity>> savedOpportunities();
  Future<UserProfile?> currentProfile();
  Future<void> updateMyProfile({
    required String displayName,
    required String username,
  });
  Future<String> uploadMyAvatar({
    required Uint8List bytes,
    required String contentType,
  });
  Future<void> acceptCommunityTerms();
  Future<List<Opportunity>> mySubmissions();
  Future<bool> isStaff();
  Future<List<DuplicateCandidate>> findDuplicates({
    required String sourceUrl,
    required String title,
    required String sourceName,
  });
  Future<String> submitOpportunity(Map<String, dynamic> draft);
  Future<void> attachSubmissionImage({
    required String opportunityId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });
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
  Future<List<Map<String, dynamic>>> opportunityMetricsForAdmin();
  Future<void> saveOpportunityMonetization({
    required String opportunityId,
    required String model,
    String? network,
    double? commissionEstimate,
    String currency = 'EUR',
    int conversions = 0,
    double revenueTotal = 0,
  });
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
  Future<void> setUserRole({
    required String id,
    required String role,
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

  Opportunity _opportunityFromMap(Map<String, dynamic> source) {
    final row = Map<String, dynamic>.from(source);
    final explicitUrl = (row['image_url'] ?? '').toString().trim();
    final storagePath = (row['image_path'] ?? '').toString().trim();

    if (explicitUrl.isEmpty && storagePath.isNotEmpty) {
      row['image_url'] = db.storage
          .from('opportunity-images')
          .getPublicUrl(storagePath);
    }

    return Opportunity.fromMap(row);
  }

  UserProfile _profileFromMap(Map<String, dynamic> source) {
    final row = Map<String, dynamic>.from(source);
    final explicitUrl = (row['avatar_url'] ?? '').toString().trim();
    final storagePath = (row['avatar_path'] ?? '').toString().trim();

    if (explicitUrl.isEmpty && storagePath.isNotEmpty) {
      row['avatar_url'] = db.storage
          .from('avatars')
          .getPublicUrl(storagePath);
    }

    return UserProfile.fromMap(row);
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
          (row) => _opportunityFromMap(
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
    return _opportunityFromMap(Map<String, dynamic>.from(row));
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
  Future<int> setVote(String opportunityId, int value) async {
    if (value != -1 && value != 1) {
      throw ArgumentError('Voto no válido.');
    }
    final result = await db.rpc(
      'set_opportunity_vote',
      params: {
        'p_opportunity_id': opportunityId,
        'p_value': value,
      },
    );
    if (result is int) return result;
    return int.tryParse(result?.toString() ?? '') ?? 0;
  }

  @override
  Future<Map<String, int>> voteStates(
    Iterable<String> opportunityIds,
  ) async {
    if (db.auth.currentUser == null) return <String, int>{};
    final ids = opportunityIds.toSet().toList(growable: false);
    if (ids.isEmpty) return <String, int>{};

    final rows = await db
        .from('opportunity_votes')
        .select('opportunity_id,value')
        .inFilter('opportunity_id', ids);

    return <String, int>{
      for (final raw in rows as List<dynamic>)
        if (raw is Map &&
            raw['opportunity_id'] != null &&
            (raw['value'] == 1 || raw['value'] == -1))
          raw['opportunity_id'].toString(): raw['value'] as int,
    };
  }

  @override
  Future<void> toggleSaved(String opportunityId) async {
    await db.rpc(
      'toggle_saved_opportunity',
      params: {'p_opportunity_id': opportunityId},
    );
  }

  @override
  Future<void> registerOutboundClick(String opportunityId) async {
    try {
      await db.rpc(
        'register_outbound_click',
        params: {'p_opportunity_id': opportunityId},
      );
    } catch (_) {
      // Analytics are deliberately best-effort and never block the user.
    }
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
          (row) => _opportunityFromMap(
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
    return _profileFromMap(Map<String, dynamic>.from(row));
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
  Future<String> uploadMyAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw ArgumentError('La imagen de perfil debe pesar menos de 5 MB.');
    }

    const allowedTypes = <String>{'image/jpeg', 'image/png', 'image/webp'};
    if (!allowedTypes.contains(contentType)) {
      throw ArgumentError('Formato de avatar no admitido.');
    }

    final bucket = db.storage.from('avatars');
    final path = '$_uid/avatar';
    final stamp = DateTime.now().millisecondsSinceEpoch;

    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
        cacheControl: '3600',
      ),
    );

    try {
      await db.rpc(
        'set_my_avatar_path',
        params: {'p_storage_path': path},
      );
    } catch (_) {
      rethrow;
    }

    final publicUrl = bucket.getPublicUrl(path);
    return '$publicUrl?v=$stamp';
  }

  @override
  Future<void> acceptCommunityTerms() async {
    await db.rpc('accept_current_terms');
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
          (row) => _opportunityFromMap(
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
  Future<String> submitOpportunity(Map<String, dynamic> draft) async {
    final row = await db.from('opportunities').insert({
      ...draft,
      'author_id': _uid,
      'status': 'pending',
      'is_verified': false,
      'affiliate_url': null,
      'is_featured': false,
      'image_url': null,
      'image_path': null,
      'photo_credit': null,
      'photo_source_url': null,
      'moderation_reason': null,
      'duplicate_of': null,
    }).select('id').single();

    return row['id'].toString();
  }

  @override
  Future<void> attachSubmissionImage({
    required String opportunityId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 8 * 1024 * 1024) {
      throw ArgumentError('La imagen debe pesar menos de 8 MB.');
    }

    final normalized = extension.toLowerCase() == 'jpeg'
        ? 'jpg'
        : extension.toLowerCase();
    const allowedExtensions = <String>{'jpg', 'png', 'webp'};
    const allowedTypes = <String>{'image/jpeg', 'image/png', 'image/webp'};

    if (!allowedExtensions.contains(normalized) ||
        !allowedTypes.contains(contentType)) {
      throw ArgumentError('Formato de imagen no admitido.');
    }

    final path = '$_uid/$opportunityId/image.$normalized';
    final bucket = db.storage.from('opportunity-images');

    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
        cacheControl: '3600',
      ),
    );

    try {
      await db.rpc(
        'attach_submission_image',
        params: {
          'p_opportunity_id': opportunityId,
          'p_storage_path': path,
        },
      );
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
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
    return (rows as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final imageUrl = (row['image_url'] ?? '').toString().trim();
      final imagePath = (row['image_path'] ?? '').toString().trim();
      if (imageUrl.isEmpty && imagePath.isNotEmpty) {
        row['image_url'] = db.storage
            .from('opportunity-images')
            .getPublicUrl(imagePath);
      }
      return row;
    }).toList();
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
          (row) => _opportunityFromMap(
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
  Future<List<Map<String, dynamic>>> opportunityMetricsForAdmin() async {
    final rows = await db.rpc('admin_opportunity_metrics');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  @override
  Future<void> saveOpportunityMonetization({
    required String opportunityId,
    required String model,
    String? network,
    double? commissionEstimate,
    String currency = 'EUR',
    int conversions = 0,
    double revenueTotal = 0,
  }) async {
    await db.rpc(
      'save_opportunity_monetization',
      params: {
        'p_opportunity_id': opportunityId,
        'p_model': model,
        'p_network': network?.trim().isEmpty == true ? null : network?.trim(),
        'p_commission_estimate': commissionEstimate,
        'p_currency': currency.trim().toUpperCase(),
        'p_conversions': conversions,
        'p_revenue_total': revenueTotal,
        'p_notes': null,
      },
    );
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
  Future<void> setUserRole({
    required String id,
    required String role,
  }) async {
    const allowed = <String>{'user', 'moderator', 'admin'};
    if (!allowed.contains(role)) {
      throw ArgumentError('Rol no válido.');
    }
    await db.rpc(
      'set_user_role',
      params: {
        'p_user_id': id,
        'p_role': role,
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

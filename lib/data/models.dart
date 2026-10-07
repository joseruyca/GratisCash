import '../core/config.dart';

enum OpportunityStatus { draft, pending, active, expired, rejected }

enum OpportunityCategory { money, freeProduct, cashback, bonus, mission }

extension OpportunityCategoryX on OpportunityCategory {
  String get label {
    switch (this) {
      case OpportunityCategory.money:
        return 'Dinero';
      case OpportunityCategory.freeProduct:
        return 'Producto gratis';
      case OpportunityCategory.cashback:
        return 'Cashback';
      case OpportunityCategory.bonus:
        return 'Bonus';
      case OpportunityCategory.mission:
        return 'Misión';
    }
  }

  static OpportunityCategory parse(String value) {
    return OpportunityCategory.values.firstWhere(
      (item) => item.name == value,
      orElse: () => OpportunityCategory.money,
    );
  }
}

class Opportunity {
  const Opportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceName,
    required this.sourceUrl,
    required this.rewardText,
    required this.category,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.estimatedMinutes,
    this.imageUrl,
    this.photoCredit,
    this.photoSourceUrl,
    this.requirements,
    this.steps = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.voteScore = 0,
    this.comments = 0,
    this.authorName = 'GratisCash',
    this.isVerified = false,
    this.isFeatured = false,
    this.affiliateUrl,
    this.isAffiliate = false,
    this.isSponsored = false,
    this.sponsorName,
    this.sponsoredFrom,
    this.sponsoredUntil,
    this.moderationReason,
    this.duplicateOf,
    this.duplicateScore,
    this.publishedAt,
    this.lastVerifiedAt,
  });

  final String id;
  final String title;
  final String description;
  final String sourceName;
  final String sourceUrl;
  final String? affiliateUrl;
  final bool isAffiliate;
  final bool isSponsored;
  final String? sponsorName;
  final DateTime? sponsoredFrom;
  final DateTime? sponsoredUntil;
  final String rewardText;
  final OpportunityCategory category;
  final OpportunityStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? estimatedMinutes;
  final String? imageUrl;
  final String? photoCredit;
  final String? photoSourceUrl;
  final String? requirements;
  final List<String> steps;
  final int upvotes;
  final int downvotes;
  final int voteScore;
  final int comments;
  final String authorName;
  final bool isVerified;
  final bool isFeatured;
  final String? moderationReason;
  final String? duplicateOf;
  final double? duplicateScore;
  final DateTime? publishedAt;
  final DateTime? lastVerifiedAt;

  bool get isExpired {
    if (status == OpportunityStatus.expired) {
      return true;
    }
    final end = expiresAt;
    return end != null && end.isBefore(DateTime.now());
  }

  bool get isRejected => status == OpportunityStatus.rejected;
  bool get hasPhoto => imageUrl != null && imageUrl!.trim().isNotEmpty;

  int? get daysRemaining {
    final end = expiresAt;
    if (end == null || isExpired) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.difference(today).inDays;
  }

  bool get endsSoon {
    final days = daysRemaining;
    return days != null && days <= 3;
  }

  String? get urgencyLabel {
    final days = daysRemaining;
    if (days == null) return null;
    if (days <= 0) return 'Último día';
    if (days == 1) return 'Termina mañana';
    if (days <= 3) return 'Termina en $days días';
    return null;
  }

  String get outboundUrl {
    final affiliate = affiliateUrl;
    if (affiliate != null && affiliate.isNotEmpty) {
      return affiliate;
    }
    return sourceUrl;
  }

  Opportunity copyWith({
    OpportunityStatus? status,
    int? upvotes,
    int? downvotes,
    int? voteScore,
    int? comments,
    bool? isFeatured,
    String? moderationReason,
    String? duplicateOf,
    double? duplicateScore,
  }) {
    return Opportunity(
      id: id,
      title: title,
      description: description,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      affiliateUrl: affiliateUrl,
      isAffiliate: isAffiliate,
      isSponsored: isSponsored,
      sponsorName: sponsorName,
      sponsoredFrom: sponsoredFrom,
      sponsoredUntil: sponsoredUntil,
      rewardText: rewardText,
      category: category,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      estimatedMinutes: estimatedMinutes,
      imageUrl: imageUrl,
      photoCredit: photoCredit,
      photoSourceUrl: photoSourceUrl,
      requirements: requirements,
      steps: steps,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      voteScore: voteScore ?? this.voteScore,
      comments: comments ?? this.comments,
      authorName: authorName,
      isVerified: isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      moderationReason: moderationReason ?? this.moderationReason,
      duplicateOf: duplicateOf ?? this.duplicateOf,
      duplicateScore: duplicateScore ?? this.duplicateScore,
      publishedAt: publishedAt,
      lastVerifiedAt: lastVerifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'affiliate_url': affiliateUrl,
      'is_affiliate': isAffiliate,
      'is_sponsored': isSponsored,
      'sponsor_name': sponsorName,
      'sponsored_from': sponsoredFrom?.toIso8601String(),
      'sponsored_until': sponsoredUntil?.toIso8601String(),
      'reward_text': rewardText,
      'category': category.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'image_url': imageUrl,
      'photo_credit': photoCredit,
      'photo_source_url': photoSourceUrl,
      'requirements': requirements,
      'steps': steps,
      'upvote_count': upvotes,
      'downvote_count': downvotes,
      'vote_score': voteScore,
      'comment_count': comments,
      'author_name': authorName,
      'is_verified': isVerified,
      'is_featured': isFeatured,
      'moderation_reason': moderationReason,
      'duplicate_of': duplicateOf,
      'duplicate_score': duplicateScore,
      'published_at': publishedAt?.toIso8601String(),
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
    };
  }

  factory Opportunity.fromMap(Map<String, dynamic> map) {
    final rawSteps = map['steps'];
    final steps = rawSteps is List
        ? rawSteps.map((item) => item.toString()).toList()
        : <String>[];

    return Opportunity(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      sourceName: (map['source_name'] ?? '').toString(),
      sourceUrl: (map['source_url'] ?? '').toString(),
      affiliateUrl: (map['outbound_url'] ?? map['affiliate_url'])?.toString(),
      isAffiliate: map['is_affiliate'] == true,
      isSponsored: map['is_sponsored'] == true,
      sponsorName: map['sponsor_name']?.toString(),
      sponsoredFrom: _dateOrNull(map['sponsored_from']),
      sponsoredUntil: _dateOrNull(map['sponsored_until']),
      rewardText: (map['reward_text'] ?? '').toString(),
      category: OpportunityCategoryX.parse(
        (map['category'] ?? 'money').toString(),
      ),
      status: OpportunityStatus.values.firstWhere(
        (item) =>
            item.name ==
            (map['effective_status'] ?? map['status'] ?? 'active').toString(),
        orElse: () => OpportunityStatus.active,
      ),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.tryParse(map['expires_at'].toString()),
      estimatedMinutes: _intOrNull(map['estimated_minutes']),
      imageUrl: map['image_url']?.toString(),
      photoCredit: map['photo_credit']?.toString(),
      photoSourceUrl: map['photo_source_url']?.toString(),
      requirements: map['requirements']?.toString(),
      steps: steps,
      upvotes: _intOrZero(map['upvote_count']),
      downvotes: _intOrZero(map['downvote_count']),
      voteScore: _intOrZero(map['vote_score']),
      comments: _intOrZero(map['comment_count']),
      authorName: (map['author_name'] ?? 'GratisCash').toString(),
      isVerified: map['is_verified'] == true,
      isFeatured: map['is_featured'] == true,
      moderationReason: map['moderation_reason']?.toString(),
      duplicateOf: map['duplicate_of']?.toString(),
      duplicateScore: _doubleOrNull(map['duplicate_score']),
      publishedAt: _dateOrNull(map['published_at']),
      lastVerifiedAt: _dateOrNull(map['last_verified_at']),
    );
  }
}

class DuplicateCandidate {
  const DuplicateCandidate({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.status,
    required this.score,
    required this.exactUrl,
  });

  final String id;
  final String title;
  final String sourceName;
  final String status;
  final double score;
  final bool exactUrl;

  bool get isStrongMatch =>
      (exactUrl && score >= 0.55) || score >= 0.78;

  factory DuplicateCandidate.fromMap(Map<String, dynamic> map) {
    return DuplicateCandidate(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      sourceName: (map['source_name'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      score: _doubleOrNull(map['score']) ?? 0,
      exactUrl: map['exact_url'] == true,
    );
  }
}

class AppComment {
  const AppComment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.createdAt,
    this.upvotes = 0,
    this.authorId,
  });

  final String id;
  final String body;
  final String authorName;
  final DateTime createdAt;
  final int upvotes;
  final String? authorId;

  factory AppComment.fromMap(Map<String, dynamic> map) {
    return AppComment(
      id: map['id'].toString(),
      body: (map['body'] ?? '').toString(),
      authorName: (map['author_name'] ?? 'Usuario').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      upvotes: _intOrZero(map['upvote_count']),
      authorId: map['author_id']?.toString(),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.isSuspended = false,
    this.termsVersion,
    this.termsAcceptedAt,
    this.adultConfirmedAt,
    this.suspensionReason,
    this.suspendedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool isSuspended;
  final String? termsVersion;
  final DateTime? termsAcceptedAt;
  final DateTime? adultConfirmedAt;
  final String? suspensionReason;
  final DateTime? suspendedAt;

  bool get isStaff => role == 'admin' || role == 'moderator';
  bool get hasCurrentCommunityConsent =>
      !isSuspended &&
      termsVersion == AppConfig.termsVersion &&
      termsAcceptedAt != null &&
      adultConfirmedAt != null;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'].toString(),
      username: (map['username'] ?? 'usuario').toString(),
      displayName: (map['display_name'] ?? 'Usuario').toString(),
      role: (map['role'] ?? 'user').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      avatarUrl: map['avatar_url']?.toString(),
      isSuspended: map['is_suspended'] == true,
      termsVersion: map['terms_version']?.toString(),
      termsAcceptedAt: _dateOrNull(map['terms_accepted_at']),
      adultConfirmedAt: _dateOrNull(map['adult_confirmed_at']),
      suspensionReason: map['suspension_reason']?.toString(),
      suspendedAt: _dateOrNull(map['suspended_at']),
    );
  }
}

class ModerationAppeal {
  const ModerationAppeal({
    required this.id,
    required this.opportunityId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.response,
    this.opportunityTitle,
    this.authorName,
  });

  final String id;
  final String opportunityId;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? response;
  final String? opportunityTitle;
  final String? authorName;

  factory ModerationAppeal.fromMap(Map<String, dynamic> map) {
    return ModerationAppeal(
      id: map['id'].toString(),
      opportunityId: map['opportunity_id'].toString(),
      message: (map['message'] ?? '').toString(),
      status: (map['status'] ?? 'open').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      response: map['response']?.toString(),
      opportunityTitle: map['opportunity_title']?.toString(),
      authorName: map['author_name']?.toString(),
    );
  }
}

int _intOrZero(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

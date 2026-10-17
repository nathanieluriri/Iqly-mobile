/// The API's polls and activations (contract 11) as tests script them, at
/// [now].
class PollsActivationsJson {
  PollsActivationsJson(this.now);

  final DateTime now;

  String at(Duration ago) => now.subtract(ago).toUtc().toIso8601String();
  String inn(Duration later) => now.add(later).toUtc().toIso8601String();

  /// The flavour poll as `GET /polls/:id` answers it.
  Map<String, Object?> pollJson({
    String id = 'p_1',
    String question = 'Which flavour should we launch first?',
    int? chosen,
    List<int>? votes,
    bool closed = false,
    String businessId = 'org_sunline',
    String businessName = 'Sunline Foods',
  }) => {
    'id': id,
    'question': question,
    'choices': ['Zobo and ginger', 'Tiger nut', 'Pineapple and mint'],
    'imageUrl': null,
    'closesAt': inn(const Duration(days: 2)),
    'closed': closed,
    'chosen': chosen,
    'votes': votes,
    'shares': null,
    'total': votes?.fold<int>(0, (a, b) => a + b),
    'business': {
      'id': businessId,
      'name': businessName,
      'logoUrl': 'https://api.test/profiles/brands/$businessId/logo',
    },
  };

  /// `GET /polls` with [polls] under their businesses, in order.
  Map<String, Object?> pollsJson(List<Map<String, Object?>> polls) {
    final businesses = <String, Map<String, Object?>>{};
    for (final poll in polls) {
      final business = poll['business']! as Map<String, Object?>;
      final held = businesses[business['id']! as String] ??= {
        ...business,
        'coverUrl': null,
        'bannerUrl': null,
        'polls': <Object?>[],
      };
      (held['polls']! as List<Object?>).add(poll);
    }
    return {'businesses': businesses.values.toList()};
  }

  /// A contract 11.2 activation with [progress].
  Map<String, Object?> activationJson({
    String id = 'a_1',
    String status = 'live',
    String title = 'Open a Harbour Telecom account and buy a 1GB plan',
    String closesAt = '',
    int spotsLeft = 498,
    Map<String, Object?>? progress,
  }) => {
    'id': id,
    'businessId': 'org_harbour',
    'businessName': 'Harbour Telecom',
    'logoUrl': 'https://api.test/profiles/brands/org_harbour/logo',
    'imageUrl': 'https://api.test/activations/$id/image?v=1',
    'title': title,
    'instructions': null,
    'minutes': 10,
    'rewardKobo': 150000,
    'closesAt': closesAt.isEmpty ? inn(const Duration(days: 2)) : closesAt,
    'status': status,
    'spotsLeft': spotsLeft,
    'spotsTotal': 500,
    'steps': [
      {'title': 'Sign up with code IQLY', 'hint': 'Enter IQLY.', 'howTo': null},
      {
        'title': 'Verify your NIN in the app',
        'hint': 'Settings → Verification',
        'howTo': 'Settings → Verification. About 2 min',
      },
      {'title': 'Buy your first 1GB plan', 'hint': 'Any plan.', 'howTo': null},
    ],
    'link': 'https://harbour.example/app',
    'proofTypes': ['video'],
    'progress': progress,
    'phase': 'offer',
  };

  Map<String, Object?> runJson({
    String status = 'started',
    List<String> confirmedAt = const [],
    String? paidAt,
    String? expiredAt,
    Map<String, Object?>? proof,
  }) => {
    'id': 'r_1',
    'status': status,
    'startedAt': at(const Duration(days: 2)),
    'confirmedAt': confirmedAt,
    'paidAt': paidAt,
    'ledgerId': paidAt == null ? null : 'l_9',
    'expiredAt': expiredAt,
    'proof': proof,
  };

  Map<String, Object?> proofJson({String status = 'pending', String? reason}) =>
      {
        'id': 'pr_1',
        'step': 1,
        'status': status,
        'receivedAt': at(const Duration(hours: 1)),
        'checkedAt': null,
        'notAccepted': reason,
        'video': {
          'name': 'proof.mp4',
          'bytes': 18000000,
          'lengthSeconds': 42,
          'url': 'https://api.test/activations/proofs/pr_1/video',
        },
      };
}

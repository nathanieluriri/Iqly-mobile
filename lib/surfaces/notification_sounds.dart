/// The iQLY notification sounds, made by tool/gen_sounds.py: Android plays
/// `res/raw/<name>.ogg`, iOS `ios/Runner/Sounds/<name>.caf`.
enum IqSound {
  bingSpark('iqly_bing_spark', 'Spark', 'A single bright bing'),
  bingIdea('iqly_bing_idea', 'Idea', 'Two notes, rising: bing-ding'),
  bingGlass('iqly_bing_glass', 'Glass', 'A glassy ping that lifts'),
  sirenWhistle('iqly_siren_whistle', 'Whistle', 'Pheeee, rising then held'),
  sirenWail('iqly_siren_wail', 'Wail', 'One soft siren swell'),
  sirenChirp('iqly_siren_chirp', 'Chirp', 'Two quick rising pheews');

  const IqSound(this.resource, this.label, this.description);

  final String resource;
  final String label;
  final String description;

  bool get isSiren => name.startsWith('siren');

  String get iosFile => '$resource.caf';

  /// The Try notifications channel that plays only this sound: Android ties
  /// a sound to its channel for good.
  String get sampleChannelId => 'sample_$resource';
}

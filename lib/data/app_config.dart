import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/money.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'live/live_repository.dart';

/// The numbers `GET /config` serves (contract 13.6) in place of the ones the
/// app shipped with. Every default is the number the app used before, so a
/// preview launch, a launch with `config` off and a field the answer leaves
/// out all read as they did.
class AppConfig {
  const AppConfig({
    this.supportEmail = 'support@iqly.net',
    this.supportMessageMaxChars = 1000,
    this.supportMaxAttachments = 3,
    this.referralRewardKobo = 50000,
    this.inviteeRewardKobo = 50000,
    this.withdrawalMinimumKobo = 100000,
    this.withdrawalMaximumKobo,
    this.pinLength = 4,
    this.maxFiles = 5,
    this.maxFileBytes = 10 * 1024 * 1024,
    this.maxTotalBytes = 30 * 1024 * 1024,
    this.pollQuestionMaxChars = 140,
    this.proofVideoMaxBytes = 50000000,
    this.proofVideoMaxSeconds = 60,
    this.phoneResendAfterSeconds = 45,
    this.closeReminderOffsets = const [60],
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> part(String key) => switch (json[key]) {
      final Map<dynamic, dynamic> map => map.cast<String, dynamic>(),
      _ => const {},
    };
    int at(Map<String, dynamic> map, String key, int fallback) =>
        switch (map[key]) {
          final num n when n > 0 => n.toInt(),
          _ => fallback,
        };
    const d = defaults;
    final support = part('support');
    final referrals = part('referrals');
    final withdrawals = part('withdrawals');
    final submissions = part('submissions');
    final polls = part('polls');
    final activations = part('activations');
    final phone = part('phone');
    final reminders = part('closeReminders');
    final email = support['email'];
    final maximum = withdrawals['maximumKobo'];
    final offsets = reminders['defaultOffsetsMinutes'];
    return AppConfig(
      supportEmail: email is String && email.contains('@')
          ? email
          : d.supportEmail,
      supportMessageMaxChars: at(
        support,
        'messageMaxChars',
        d.supportMessageMaxChars,
      ),
      supportMaxAttachments: at(
        support,
        'maxAttachments',
        d.supportMaxAttachments,
      ),
      referralRewardKobo: at(referrals, 'rewardKobo', d.referralRewardKobo),
      inviteeRewardKobo: at(
        referrals,
        'inviteeRewardKobo',
        d.inviteeRewardKobo,
      ),
      withdrawalMinimumKobo: at(
        withdrawals,
        'minimumKobo',
        d.withdrawalMinimumKobo,
      ),
      withdrawalMaximumKobo: maximum is num && maximum > 0
          ? maximum.toInt()
          : null,
      pinLength: at(withdrawals, 'pinLength', d.pinLength),
      maxFiles: at(submissions, 'maxFiles', d.maxFiles),
      maxFileBytes: at(submissions, 'maxFileBytes', d.maxFileBytes),
      maxTotalBytes: at(submissions, 'maxTotalBytes', d.maxTotalBytes),
      pollQuestionMaxChars: at(
        polls,
        'questionMaxChars',
        d.pollQuestionMaxChars,
      ),
      proofVideoMaxBytes: at(
        activations,
        'proofVideoMaxBytes',
        d.proofVideoMaxBytes,
      ),
      proofVideoMaxSeconds: at(
        activations,
        'proofVideoMaxSeconds',
        d.proofVideoMaxSeconds,
      ),
      phoneResendAfterSeconds: at(
        phone,
        'resendAfterSeconds',
        d.phoneResendAfterSeconds,
      ),
      closeReminderOffsets: offsets is List && offsets.isNotEmpty
          ? [
              for (final o in offsets)
                if (o is num && o > 0) o.toInt(),
            ]
          : d.closeReminderOffsets,
    );
  }

  static const defaults = AppConfig();

  /// The launch's settings, for the rules read outside a widget (the proof
  /// recording's limits, the withdrawal floor). [appConfigProvider] keeps it
  /// in step.
  static AppConfig current = defaults;

  final String supportEmail;
  final int supportMessageMaxChars;
  final int supportMaxAttachments;
  final int referralRewardKobo;
  final int inviteeRewardKobo;
  final int withdrawalMinimumKobo;

  /// Null: no cap beyond the withdrawable balance.
  final int? withdrawalMaximumKobo;
  final int pinLength;
  final int maxFiles;
  final int maxFileBytes;
  final int maxTotalBytes;
  final int pollQuestionMaxChars;
  final int proofVideoMaxBytes;
  final int proofVideoMaxSeconds;
  final int phoneResendAfterSeconds;

  /// Minutes before close a new reminder fires.
  final List<int> closeReminderOffsets;
}

/// "₦500": what a referral pays, as the referral screens word it.
String referralReward() => rewardPool(AppConfig.current.referralRewardKobo);

/// The settings this launch runs on: the copy the last `GET /config` left
/// on the phone while `config` is live, the shipped numbers otherwise.
/// [refresh] asks again without holding anything up.
class AppConfigNotifier extends Notifier<AppConfig> {
  static const key = 'config.app';

  bool get _live =>
      ref.watch(liveModeProvider).isLive(LiveFeature.config) &&
      ref.watch(apiClientProvider) != null;

  @override
  AppConfig build() {
    var config = AppConfig.defaults;
    if (_live) {
      final raw = ref.read(sharedPreferencesProvider).getString(key);
      if (raw != null) {
        try {
          config = AppConfig.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>(),
          );
        } on Object {
          config = AppConfig.defaults;
        }
      }
    }
    return AppConfig.current = config;
  }

  /// Reads `GET /config` and keeps it for this launch and the next. No
  /// answer keeps what the phone has.
  Future<void> refresh() async {
    final api = ref.read(apiClientProvider);
    if (api == null || !ref.read(liveModeProvider).isLive(LiveFeature.config)) {
      return;
    }
    try {
      final res = await api.get('/config');
      if (!res.ok || res.data.isEmpty || !ref.mounted) return;
      await ref
          .read(sharedPreferencesProvider)
          .setString(key, jsonEncode(res.data));
      if (!ref.mounted) return;
      state = AppConfig.current = AppConfig.fromJson(res.data);
    } on Object catch (error) {
      debugPrint('Config: kept the last copy: $error');
    }
  }
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

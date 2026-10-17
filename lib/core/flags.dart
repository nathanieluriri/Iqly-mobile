/// Design proposals the API may lag behind. Each ships behind its flag so a
/// screen can hide the feature without a redesign.
abstract final class Flags {
  static const polls = true;
  static const activations = true;
  static const savedBriefs = true;
  static const closeReminders = true;
  static const businessNote = true;
  static const notificationPreferences = true;
  static const deleteAccount = true;

  /// First run forks on what people do (owner, 16 Oct): a student says where
  /// they study and anyone else what their work is, before where they live.
  /// Off puts back the order before, where everyone gives an education.
  static const onboardingByOccupation = true;

  /// The API sends no push yet; local notifications stand in for it.
  static const pushNotifications = true;
  static const homeWidgets = true;
  static const payoutLiveActivity = true;
}

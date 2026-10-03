import '../data/models.dart';
import '../data/reference_data.dart';

/// Ticket stub capacity: "12 spots left", or "No limit" for open capacity.
String spotsLeftLabel(Brief brief) {
  final left = brief.spotsLeft;
  if (left == null) return 'No limit';
  return '$left ${left == 1 ? 'spot' : 'spots'} left';
}

/// Ticket meta: "Sunline · Standard".
String ticketMeta(Brief brief) =>
    [?brief.businessName, brief.tier.label].join(' · ');

String businessInitial(Brief brief) =>
    (brief.businessName ?? brief.title).substring(0, 1);

String? interestLabel(String? value) {
  for (final option in Reference.interests) {
    if (option.value == value) return option.label;
  }
  return null;
}

import '../data/models.dart';
import '../ui/sample_logo.dart';

/// "6h", "1 day", "25 days", "40 min", rounded down like closesIn.
String leftShort(Duration left) {
  if (left.inHours < 1) return '${left.inMinutes} min';
  if (left.inHours < 24) return '${left.inHours}h';
  final days = left.inDays;
  return '$days ${days == 1 ? 'day' : 'days'}';
}

/// "6 hours", "1 day", "40 minutes".
String leftLong(Duration left) {
  final (n, unit) = left.inHours < 1
      ? (left.inMinutes, 'minute')
      : left.inHours < 24
      ? (left.inHours, 'hour')
      : (left.inDays, 'day');
  return '$n $unit${n == 1 ? '' : 's'}';
}

/// The sample art for a business; a brief without one is Private.
IqSampleLogoBrand brandOf(String? businessName) {
  if (businessName == null) return IqSampleLogoBrand.private;
  for (final brand in IqSampleLogoBrand.values) {
    if (businessName == brand.label || businessName.startsWith(brand.label)) {
      return brand;
    }
  }
  return IqSampleLogoBrand.private;
}

IqSampleLogoBrand brandOfBrief(Brief brief) => brandOf(brief.businessName);

IqSampleLogoBrand brandOfSlug(String slug) => IqSampleLogoBrand.values
    .firstWhere((b) => b.slug == slug, orElse: () => IqSampleLogoBrand.private);

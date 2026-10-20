import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../data/onboarding_service.dart';
import '../../data/phone_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../more/more_widgets.dart';
import 'profile_routes.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/onboarding_flow.dart';
import 'profile_state.dart';

/// One row of Your details and the Edit page it opens.
enum DetailField {
  phone('phone', 'Phone number', IqIcons.phone),
  dateOfBirth('date-of-birth', 'Date of birth', IqIcons.cake),
  gender('gender', 'Gender', IqIcons.profile),
  state('state', 'State', IqIcons.pin),
  university('university', 'University', IqIcons.graduation),
  interests('interests', 'Interests', IqIcons.heart),
  occupation('occupation', 'Occupation', IqIcons.briefcase),
  city('city', 'City', IqIcons.building),
  education('education', 'Education', IqIcons.book);

  const DetailField(this.slug, this.label, this.icon);

  final String slug;
  final String label;
  final IqIcons icon;

  static DetailField? of(String slug) =>
      values.where((f) => f.slug == slug).firstOrNull;
}

/// The Figma wording of the occupation values (484:22898): "Looking for
/// work" where the shipped list says Unemployed.
const occupationLabels = {
  'student': 'Student',
  'entrepreneur': 'Entrepreneur',
  'employed': 'Employed',
  'self_employed': 'Self-employed',
  'unemployed': 'Looking for work',
  'other': 'Other',
};

/// Edit · Education (484:22815) offers four levels over the shipped five
/// values; Other stays readable for accounts that hold it.
const educationOptions = [
  RefOption('ssce', 'Secondary school'),
  RefOption('nd_nce', 'Diploma or HND'),
  RefOption('hnd_bsc', 'Bachelor’s degree'),
  RefOption('postgraduate', 'Master’s or above'),
];

String? educationLabel(String? value) =>
    optionLabel(educationOptions, value) ??
    optionLabel(Reference.education, value);

/// What each row reads, from the account and the first-run answers.
String detailValue(
  DetailField field,
  AccountDetails? details,
  OnboardingProfile answers,
) => switch (field) {
  DetailField.phone => details?.phone ?? '',
  DetailField.dateOfBirth =>
    details?.dateOfBirth == null ? '' : birthDate(details!.dateOfBirth!),
  DetailField.gender =>
    optionLabel(Reference.genders, profileGender(details, answers)) ??
        optionLabel(Reference.genders, 'prefer_not_to_say')!,
  DetailField.state => answers.state ?? '',
  DetailField.university => answers.university ?? '',
  DetailField.interests => interestsLine(answers.interests),
  DetailField.occupation => occupationLine(answers),
  DetailField.city => [
    ?answers.state,
    if (answers.city.isNotEmpty) answers.city,
  ].join(' · '),
  DetailField.education => educationLabel(answers.education) ?? '',
};

/// The gender the account holds, else the one given at first run. No
/// answer at all counts as Prefer not to say (owner, 20 Oct).
String? profileGender(AccountDetails? details, OnboardingProfile answers) =>
    details?.gender ?? answers.gender;

/// "Employed · Banking & finance": the occupation, then the sector when the
/// occupation path asks for one and it has been given.
String occupationLine(OnboardingProfile answers) {
  final occupation = occupationLabels[answers.occupation] ?? '';
  final sector = answers.sector == OnboardingFlow.otherSector
      ? answers.otherSector.trim()
      : optionLabel(Reference.sectors, answers.sector) ?? '';
  return [occupation, sector].where((s) => s.isNotEmpty).join(' · ');
}

/// Education and University only on a path that asks where someone
/// studies, and University only when the answers name one.
bool detailShown(DetailField field, OnboardingProfile answers) =>
    switch (field) {
      DetailField.education =>
        OnboardingFlow.current
            .path(answers)
            .contains(OnboardingStep.whereYouStudied),
      DetailField.university =>
        detailShown(DetailField.education, answers) &&
            Reference.namesUniversity(answers.occupation, answers.education),
      _ => true,
    };

/// B7 · Your details (40:141, Gender row 1599:33173): nine rows, each with its own filled icon
/// (designer answer, 5 Oct) and the value under the label. A row opens its
/// Edit page; edits come back here on Save. While the API sends SMS codes
/// a number its code confirmed reads "· Verified" (no frame draws it).
class YourDetailsScreen extends ConsumerWidget {
  const YourDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(accountDetailsProvider).value;
    final answers = ref.watch(profileAnswersProvider);
    final verified =
        ref.watch(phoneServiceProvider) != null &&
        (details?.phoneVerified ?? false);
    return SubPage(
      title: 'Your details',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          for (final field in DetailField.values)
            if (detailShown(field, answers))
              IqListRow(
                label: field.label,
                description: field == DetailField.phone && verified
                    ? '${detailValue(field, details, answers)} · Verified'
                    : detailValue(field, details, answers),
                icon: field.icon,
                onTap: () => context.open(editDetailPath(field)),
              ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Tap a row to change it. Your email stays as your sign-in.',
            style: IqText.small.copyWith(color: IqColors.fg3),
          ),
        ],
      ),
    );
  }
}

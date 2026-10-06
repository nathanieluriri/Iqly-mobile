import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/reference_data.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_draft.dart';
import 'package:iqly_mobile/features/onboarding/onboarding_sheets.dart';

void main() {
  test('alternate spellings find the listed city', () {
    expect(searchCities('Oyo', 'shaki'), ['Saki']);
    expect(searchCities('Oyo', 'Ogbomosho'), ['Ogbomoso']);
    expect(searchCities('Osun', 'oshogbo'), ['Osogbo']);
    expect(searchCities('Kebbi', 'Yelwa'), ['Yauri']);
  });

  test('spacing, hyphens and apostrophes do not matter', () {
    expect(searchCities('Ekiti', 'ado ekiti'), ['Ado-Ekiti']);
    expect(searchCities('Bauchi', 'jamaare'), ["Jama'are"]);
    expect(searchCities('Benue', 'zaki-biam'), ['Zaki Biam']);
  });

  test('an alternate spelling counts as listed, so Add my city stays off', () {
    expect(listedCity('Ogun', 'Shagamu'), 'Sagamu');
    expect(listedCity('Osun', 'Ife'), 'Ile-Ife');
    expect(listedCity('Lagos', 'FESTAC'), 'Festac Town');
    expect(listedCity('Lagos', 'Somewhere new'), null);
  });

  test('every alternate belongs to a listed city', () {
    final listed = {for (final v in Reference.cities.values) ...v};
    expect(
      Reference.cityAlternates.keys.where((c) => !listed.contains(c)),
      isEmpty,
    );
  });

  test('Madalla is in Niger, not the FCT', () {
    expect(Reference.cities['Niger'], contains('Madalla'));
    expect(Reference.cities['FCT - Abuja'], isNot(contains('Madalla')));
  });
}

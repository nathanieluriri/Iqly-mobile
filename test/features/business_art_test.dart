import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/business_art.dart';
import 'package:iqly_mobile/ui/image_placeholder.dart';

void main() {
  testWidgets('a network logo keeps a placeholder while the image loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: businessLogo('https://cdn.example/logo.png', size: 40),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.loadingBuilder, isNotNull);
    final loading = image.loadingBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox.shrink(),
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 10),
    );
    expect(find.byWidget(loading), findsNothing);
    expect(loading, isA<IqImagePlaceholder>());
  });

  testWidgets('a network cover keeps a placeholder while the image loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: businessCover('https://cdn.example/cover.jpg'),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final loading = image.loadingBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox.shrink(),
      const ImageChunkEvent(cumulativeBytesLoaded: 4, expectedTotalBytes: 20),
    );
    expect(loading, isA<IqImagePlaceholder>());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/business_art.dart';
import 'package:iqly_mobile/ui/image_placeholder.dart';
import 'package:iqly_mobile/ui/network_image.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets('a network logo uses the cached image with a shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: Color(0xFFFFFFFF),
            child: SizedBox(width: 40, height: 40, child: _Logo()),
          ),
        ),
      ),
    );
    expect(find.byType(IqNetworkImage), findsOneWidget);
    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(IqImagePlaceholder), findsOneWidget);
  });

  testWidgets('a network cover uses the cached image with a shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 200, height: 120, child: _Cover()),
        ),
      ),
    );
    expect(find.byType(IqNetworkImage), findsOneWidget);
    expect(find.byType(Shimmer), findsOneWidget);
  });
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) =>
      businessLogo('https://cdn.example/logo.png', size: 40);
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) =>
      businessCover('https://cdn.example/cover.jpg');
}

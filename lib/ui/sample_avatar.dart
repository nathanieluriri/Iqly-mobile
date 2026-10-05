import 'package:flutter/widgets.dart';

/// Figma Person=1 to Person=6.
enum IqSampleAvatarPerson {
  person1,
  person2,
  person3,
  person4,
  person5,
  person6;

  String get asset => 'assets/samples/avatars/person-${index + 1}.jpg';
}

/// Sample/Avatar: a round sample portrait, 120 x 120 in Figma, drawn at
/// [size]. The file is the square source photo; the circle is the clip.
class IqSampleAvatar extends StatelessWidget {
  const IqSampleAvatar({
    super.key,
    this.person = IqSampleAvatarPerson.person1,
    this.size = 120,
  });

  final IqSampleAvatarPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        person.asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
  }
}

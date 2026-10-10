import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'avatar_art.dart';
import 'icon.dart';

/// A Figma variant value.
abstract interface class _Variant {
  String get figma;
}

/// The hairstyle choice: Hair front's Style, which Afro, Puffs, Bun and Locs
/// pair with the Hair back of the same name.
enum IqAvatarHairStyle implements _Variant {
  bald('Bald'),
  lowCut('Low cut'),
  highTop('High top'),
  afro('Afro'),
  puffs('Puffs'),
  bun('Bun'),
  locs('Locs'),
  cornrows('Cornrows');

  const IqAvatarHairStyle(this.figma);
  @override
  final String figma;
}

/// Exp/Avatar/Face Expression.
enum IqAvatarExpression implements _Variant {
  smile('Smile'),
  grin('Grin'),
  wink('Wink'),
  calm('Calm'),
  wow('Wow');

  const IqAvatarExpression(this.figma);
  @override
  final String figma;
}

/// Exp/Avatar/Facial hair Style.
enum IqAvatarFacialHairStyle implements _Variant {
  none('None'),
  moustache('Moustache'),
  goatee('Goatee'),
  beard('Beard'),
  stubble('Stubble');

  const IqAvatarFacialHairStyle(this.figma);
  @override
  final String figma;
}

/// Exp/Avatar/Glasses Style.
enum IqAvatarGlassesStyle implements _Variant {
  none('None'),
  round('Round'),
  square('Square'),
  shades('Shades');

  const IqAvatarGlassesStyle(this.figma);
  @override
  final String figma;
}

/// Exp/Avatar/Headwear Style. Gele and Beanie hide both hair layers; Cap and
/// Kufi hide the hair back.
enum IqAvatarHeadwearStyle implements _Variant {
  none('None'),
  cap('Cap'),
  beanie('Beanie'),
  kufi('Kufi'),
  gele('Gele');

  const IqAvatarHeadwearStyle(this.figma);
  @override
  final String figma;

  bool get hidesHairBack => this != none;
  bool get hidesHairFront => this == gele || this == beanie;
}

/// Exp/Avatar/Body Style.
enum IqAvatarBodyStyle implements _Variant {
  tee('Tee'),
  hoodie('Hoodie'),
  shirt('Shirt'),
  kaftan('Kaftan');

  const IqAvatarBodyStyle(this.figma);
  @override
  final String figma;
}

/// Exp/Avatar/Buddy Kind.
enum IqAvatarBuddyKind implements _Variant {
  bean('Bean'),
  box('Box'),
  blob('Blob'),
  paw('Paw'),
  spark('Spark'),
  moon('Moon'),
  drop('Drop'),
  cloud('Cloud');

  const IqAvatarBuddyKind(this.figma);
  @override
  final String figma;
}

/// The layers of Exp/Avatar/Character, back to front.
enum IqAvatarPart {
  hairBack,
  body,
  head,
  face,
  facialHair,
  hairFront,
  glasses,
  headwear;

  List<AvatarNode> art(IqAvatarLook look) => switch (this) {
    hairBack =>
      look.headwear.hidesHairBack
          ? const []
          : IqAvatarArt.hairBack[look.hairStyle.figma] ?? const [],
    body => IqAvatarArt.body[look.body.figma]!,
    head => IqAvatarArt.head,
    face => IqAvatarArt.face[look.expression.figma]!,
    facialHair => IqAvatarArt.facialHair[look.facialHair.figma] ?? const [],
    hairFront =>
      look.headwear.hidesHairFront
          ? const []
          : IqAvatarArt.hairFront[look.hairStyle.figma]!,
    glasses => IqAvatarArt.glasses[look.glasses.figma] ?? const [],
    headwear => IqAvatarArt.headwear[look.headwear.figma] ?? const [],
  };
}

/// An illustrated person: the part styles and the Avatar colours, numbered
/// from 1 as the variables are (skin/4 is [skin] 4). Facial hair takes its
/// own hair colour and headwear its own cloth colour.
@immutable
class IqAvatarLook {
  const IqAvatarLook({
    this.skin = 3,
    this.hair = 1,
    this.eye = 1,
    this.hairStyle = IqAvatarHairStyle.lowCut,
    this.expression = IqAvatarExpression.smile,
    this.facialHair = IqAvatarFacialHairStyle.none,
    this.facialHairColour = 1,
    this.glasses = IqAvatarGlassesStyle.none,
    this.headwear = IqAvatarHeadwearStyle.none,
    this.headwearColour = 1,
    this.body = IqAvatarBodyStyle.tee,
    this.cloth = 1,
    this.bg = 1,
  });

  final int skin;
  final int hair;
  final int eye;
  final IqAvatarHairStyle hairStyle;
  final IqAvatarExpression expression;
  final IqAvatarFacialHairStyle facialHair;
  final int facialHairColour;
  final IqAvatarGlassesStyle glasses;
  final IqAvatarHeadwearStyle headwear;
  final int headwearColour;
  final IqAvatarBodyStyle body;
  final int cloth;
  final int bg;

  Color get background => IqAvatarColors.bg[bg - 1];

  /// The slots the record fills in the part art.
  Map<String, Color> get colours => {
    'skin': IqAvatarColors.skin[skin - 1],
    'skinShade': IqAvatarColors.skinShade[skin - 1],
    'hair': IqAvatarColors.hair[hair - 1],
    'facialHair': IqAvatarColors.hair[facialHairColour - 1],
    'eye': IqAvatarColors.eye[eye - 1],
    'cloth': IqAvatarColors.cloth[cloth - 1],
    'clothShade': IqAvatarColors.clothShade[cloth - 1],
    'headwear': IqAvatarColors.cloth[headwearColour - 1],
    'headwearShade': IqAvatarColors.clothShade[headwearColour - 1],
  };

  List<List<AvatarNode>> get layers => [
    for (final part in IqAvatarPart.values) part.art(this),
  ];

  IqAvatarLook copyWith({
    int? skin,
    int? hair,
    int? eye,
    IqAvatarHairStyle? hairStyle,
    IqAvatarExpression? expression,
    IqAvatarFacialHairStyle? facialHair,
    int? facialHairColour,
    IqAvatarGlassesStyle? glasses,
    IqAvatarHeadwearStyle? headwear,
    int? headwearColour,
    IqAvatarBodyStyle? body,
    int? cloth,
    int? bg,
  }) => IqAvatarLook(
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    eye: eye ?? this.eye,
    hairStyle: hairStyle ?? this.hairStyle,
    expression: expression ?? this.expression,
    facialHair: facialHair ?? this.facialHair,
    facialHairColour: facialHairColour ?? this.facialHairColour,
    glasses: glasses ?? this.glasses,
    headwear: headwear ?? this.headwear,
    headwearColour: headwearColour ?? this.headwearColour,
    body: body ?? this.body,
    cloth: cloth ?? this.cloth,
    bg: bg ?? this.bg,
  );

  /// The stored record (designer doc, 6 Oct): {skin: 4, hair: 1, eye: 1,
  /// hairStyle: 'Puffs', face: 'Smile', facialHair: 'None', ...}.
  Map<String, Object> toJson() => {
    'skin': skin,
    'hair': hair,
    'eye': eye,
    'hairStyle': hairStyle.figma,
    'face': expression.figma,
    'facialHair': facialHair.figma,
    'facialHairColour': facialHairColour,
    'glasses': glasses.figma,
    'headwear': headwear.figma,
    'headwearColour': headwearColour,
    'body': body.figma,
    'cloth': cloth,
    'bg': bg,
  };

  /// Null when the record names a part or colour this build does not have.
  static IqAvatarLook? fromJson(Map<String, Object?> json) {
    T? named<T extends _Variant>(List<T> values, Object? figma) =>
        values.where((v) => v.figma == figma).firstOrNull;
    int? index(Object? value, int count) =>
        value is int && value >= 1 && value <= count ? value : null;
    final skin = index(json['skin'], IqAvatarColors.skin.length);
    final hair = index(json['hair'], IqAvatarColors.hair.length);
    final eye = index(json['eye'], IqAvatarColors.eye.length);
    final hairStyle = named(IqAvatarHairStyle.values, json['hairStyle']);
    final expression = named(IqAvatarExpression.values, json['face']);
    final facialHair = named(
      IqAvatarFacialHairStyle.values,
      json['facialHair'],
    );
    final facialHairColour = index(
      json['facialHairColour'],
      IqAvatarColors.hair.length,
    );
    final glasses = named(IqAvatarGlassesStyle.values, json['glasses']);
    final headwear = named(IqAvatarHeadwearStyle.values, json['headwear']);
    final headwearColour = index(
      json['headwearColour'],
      IqAvatarColors.cloth.length,
    );
    final body = named(IqAvatarBodyStyle.values, json['body']);
    final cloth = index(json['cloth'], IqAvatarColors.cloth.length);
    final bg = index(json['bg'], IqAvatarColors.bg.length);
    if (skin == null ||
        hair == null ||
        eye == null ||
        hairStyle == null ||
        expression == null ||
        facialHair == null ||
        facialHairColour == null ||
        glasses == null ||
        headwear == null ||
        headwearColour == null ||
        body == null ||
        cloth == null ||
        bg == null) {
      return null;
    }
    return IqAvatarLook(
      skin: skin,
      hair: hair,
      eye: eye,
      hairStyle: hairStyle,
      expression: expression,
      facialHair: facialHair,
      facialHairColour: facialHairColour,
      glasses: glasses,
      headwear: headwear,
      headwearColour: headwearColour,
      body: body,
      cloth: cloth,
      bg: bg,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IqAvatarLook && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// What a person shows as: an illustrated person, a buddy, an emoji on a
/// background colour or their own photo. Every kind is a 120 circle, so any
/// of them stands in wherever an avatar shows.
sealed class IqAvatarSpec {
  const IqAvatarSpec();

  /// The kind and its data; a photo's bytes are kept apart.
  Map<String, Object> toJson();

  static IqAvatarSpec? fromJson(Map<String, Object?> json, {Uint8List? photo}) {
    return switch (json['kind']) {
      'person' => switch (json['person']) {
        final Map<String, Object?> person => switch (IqAvatarLook.fromJson(
          person,
        )) {
          final look? => IqPersonAvatar(look),
          null => null,
        },
        _ => null,
      },
      'buddy' => switch (IqAvatarBuddyKind.values
          .where((k) => k.figma == json['buddy'])
          .firstOrNull) {
        final kind? => IqBuddyAvatar(kind),
        null => null,
      },
      'emoji' => switch ((json['emoji'], json['bg'])) {
        (final String emoji, final int bg)
            when bg >= 1 && bg <= IqAvatarColors.bg.length =>
          IqEmojiAvatar(emoji, bg: bg),
        _ => null,
      },
      'photo' => photo == null ? null : IqPhotoAvatar(photo),
      _ => null,
    };
  }
}

final class IqPersonAvatar extends IqAvatarSpec {
  const IqPersonAvatar(this.look);

  final IqAvatarLook look;

  @override
  Map<String, Object> toJson() => {'kind': 'person', 'person': look.toJson()};

  @override
  bool operator ==(Object other) =>
      other is IqPersonAvatar && other.look == look;

  @override
  int get hashCode => look.hashCode;
}

final class IqBuddyAvatar extends IqAvatarSpec {
  const IqBuddyAvatar(this.kind);

  final IqAvatarBuddyKind kind;

  @override
  Map<String, Object> toJson() => {'kind': 'buddy', 'buddy': kind.figma};

  @override
  bool operator ==(Object other) =>
      other is IqBuddyAvatar && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// Exp/Avatar/Emoji's background is bg/5 unless set.
final class IqEmojiAvatar extends IqAvatarSpec {
  const IqEmojiAvatar(this.emoji, {this.bg = 5});

  final String emoji;
  final int bg;

  @override
  Map<String, Object> toJson() => {'kind': 'emoji', 'emoji': emoji, 'bg': bg};

  @override
  bool operator ==(Object other) =>
      other is IqEmojiAvatar && other.emoji == emoji && other.bg == bg;

  @override
  int get hashCode => Object.hash(emoji, bg);
}

final class IqPhotoAvatar extends IqAvatarSpec {
  const IqPhotoAvatar(this.bytes);

  final Uint8List bytes;

  @override
  Map<String, Object> toJson() => {'kind': 'photo'};

  @override
  bool operator ==(Object other) =>
      other is IqPhotoAvatar &&
      (identical(other.bytes, bytes) || listEquals(other.bytes, bytes));

  @override
  int get hashCode => Object.hash(bytes.length, bytes.firstOrNull);
}

abstract final class IqAvatarPresets {
  /// Sample/Avatar Person=1 to Person=6 (DS 295:1356 to 295:1361).
  static const person1 = IqAvatarLook(
    skin: 4,
    hairStyle: IqAvatarHairStyle.puffs,
    body: IqAvatarBodyStyle.kaftan,
  );
  static const person2 = IqAvatarLook(
    skin: 2,
    hairStyle: IqAvatarHairStyle.lowCut,
    expression: IqAvatarExpression.grin,
    facialHair: IqAvatarFacialHairStyle.beard,
    glasses: IqAvatarGlassesStyle.square,
    body: IqAvatarBodyStyle.shirt,
    cloth: 5,
    bg: 2,
  );
  static const person3 = IqAvatarLook(
    skin: 5,
    hairStyle: IqAvatarHairStyle.highTop,
    expression: IqAvatarExpression.wink,
    body: IqAvatarBodyStyle.hoodie,
    cloth: 2,
    bg: 3,
  );
  static const person4 = IqAvatarLook(
    hairStyle: IqAvatarHairStyle.bald,
    glasses: IqAvatarGlassesStyle.round,
    headwear: IqAvatarHeadwearStyle.gele,
    headwearColour: 2,
    body: IqAvatarBodyStyle.kaftan,
    cloth: 2,
    bg: 5,
  );
  static const person5 = IqAvatarLook(
    skin: 6,
    hair: 4,
    hairStyle: IqAvatarHairStyle.afro,
    expression: IqAvatarExpression.wow,
    cloth: 4,
    bg: 6,
  );
  static const person6 = IqAvatarLook(
    skin: 1,
    hairStyle: IqAvatarHairStyle.locs,
    expression: IqAvatarExpression.calm,
    facialHair: IqAvatarFacialHairStyle.stubble,
    cloth: 3,
    bg: 10,
  );
  static const people = [person1, person2, person3, person4, person5, person6];

  /// The Emojis of Exp/AvatarSheet.
  static const emojis = [
    '😀',
    '😄',
    '😁',
    '😎',
    '🤩',
    '🥳',
    '😇',
    '🙂',
    '😉',
    '🤓',
    '😌',
    '😍',
  ];
}

/// Any [IqAvatarSpec] as a circle [size] across.
class IqAvatar extends StatelessWidget {
  const IqAvatar(this.spec, {super.key, this.size = 120});

  final IqAvatarSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: switch (spec) {
        IqPersonAvatar(:final look) => ClipOval(
          child: IqAvatarCharacter(look: look, size: size),
        ),
        IqBuddyAvatar(:final kind) => IqAvatarBuddy(kind: kind, size: size),
        IqEmojiAvatar(:final emoji, :final bg) => IqAvatarEmoji(
          emoji: emoji,
          bg: bg,
          size: size,
        ),
        IqPhotoAvatar(:final bytes) => IqAvatarPhoto(photo: bytes, size: size),
      },
    );
  }
}

/// Exp/Avatar/Character: the person's parts on a 240 square filled with
/// their background, drawn at [size]. [scales] pops a part about its own
/// centre (the editor's 160 ms swap).
class IqAvatarCharacter extends StatelessWidget {
  const IqAvatarCharacter({
    super.key,
    required this.look,
    this.size = 240,
    this.showBackground = true,
    this.scales = const {},
  });

  final IqAvatarLook look;
  final double size;

  /// Off in Exp/Avatar/OptionTile, which sits the person on its own tint.
  final bool showBackground;
  final Map<IqAvatarPart, double> scales;

  static final _centres = Expando<Offset>();

  /// The centre of [layer]'s shapes on the 240 canvas.
  static Offset centreOf(List<AvatarNode> layer) {
    if (layer.isEmpty) return const Offset(120, 120);
    return _centres[layer] ??= () {
      Rect? bounds;
      void visit(List<AvatarNode> nodes) {
        for (final node in nodes) {
          switch (node) {
            case AvatarShape():
              final b = AvatarArtPainter.boundsOf(node.d);
              bounds = bounds?.expandToInclude(b) ?? b;
            case AvatarGroup():
              visit(node.children);
          }
        }
      }

      visit(layer);
      return bounds!.center;
    }();
  }

  @override
  Widget build(BuildContext context) {
    final layers = look.layers;
    final popping = scales.values.any((s) => s != 1);
    final art = CustomPaint(
      size: Size.square(size),
      painter: AvatarArtPainter(
        layers: layers,
        colours: look.colours,
        scales: [
          if (popping)
            for (final part in IqAvatarPart.values) scales[part] ?? 1,
        ],
        pivots: [
          if (popping)
            for (final layer in layers) centreOf(layer),
        ],
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: showBackground
            ? ColoredBox(color: look.background, child: art)
            : art,
      ),
    );
  }
}

/// Exp/Avatar/Buddy: a character with its own colours, a 120 circle drawn
/// at [size].
class IqAvatarBuddy extends StatelessWidget {
  const IqAvatarBuddy({
    super.key,
    this.kind = IqAvatarBuddyKind.bean,
    this.size = 120,
  });

  final IqAvatarBuddyKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: AvatarArtPainter(
        layers: [IqAvatarArt.buddy[kind.figma]!],
        canvas: 120,
      ),
    );
  }
}

/// Exp/Avatar/Emoji: an emoji in the system emoji font on an Avatar bg
/// colour, a 120 circle drawn at [size].
class IqAvatarEmoji extends StatelessWidget {
  const IqAvatarEmoji({
    super.key,
    this.emoji = '😄',
    this.bg = 5,
    this.size = 120,
  });

  final String emoji;
  final int bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IqAvatarColors.bg[bg - 1],
        shape: BoxShape.circle,
      ),
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: IqText.emoji.copyWith(
          fontSize: IqText.emoji.fontSize! * size / 120,
        ),
      ),
    );
  }
}

/// Exp/Avatar/Photo: the person's own photo cropped to a 120 circle, drawn
/// at [size]; without one, the camera on tint.
class IqAvatarPhoto extends StatelessWidget {
  const IqAvatarPhoto({super.key, this.photo, this.size = 120});

  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo != null) {
      return ClipOval(
        child: Image.memory(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IqColors.tint,
        shape: BoxShape.circle,
      ),
      child: Opacity(
        opacity: 0.35,
        child: IqIcon(IqIcons.camera, size: size / 3, color: IqColors.brand),
      ),
    );
  }
}

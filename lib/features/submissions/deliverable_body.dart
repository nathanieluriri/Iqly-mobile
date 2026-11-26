/// One deliverable prompt and the answer written for it. [prompt] is null
/// when the body is a single free-text answer.
class DeliverablePair {
  const DeliverablePair({required this.prompt, required this.answer});

  final String? prompt;
  final String answer;

  @override
  bool operator ==(Object other) =>
      other is DeliverablePair &&
      other.prompt == prompt &&
      other.answer == answer;

  @override
  int get hashCode => Object.hash(prompt, answer);
}

/// The stored body as prompt/answer pairs, or one free-text block.
List<DeliverablePair> parseDeliverablePairs(String body) {
  final text = body.trim();
  if (text.isEmpty) return const [];
  final sections = [
    for (final section in text.split(RegExp(r'\n\s*\n')))
      if (section.trim().isNotEmpty) section.trim(),
  ];
  if (sections.isEmpty) return const [];
  if (sections.every((section) => section.contains('\n'))) {
    return [
      for (final section in sections)
        DeliverablePair(
          prompt: section.substring(0, section.indexOf('\n')).trim(),
          answer: section.substring(section.indexOf('\n') + 1).trim(),
        ),
    ];
  }
  if (sections.length >= 2 && sections.length.isEven) {
    return [
      for (var i = 0; i < sections.length; i += 2)
        DeliverablePair(prompt: sections[i], answer: sections[i + 1]),
    ];
  }
  return [DeliverablePair(prompt: null, answer: text)];
}

bool needsSeeMore(DeliverablePair pair) {
  if (pair.prompt == null) return pair.answer.length > 180;
  return pair.prompt!.length > 90 || pair.answer.length > 160;
}

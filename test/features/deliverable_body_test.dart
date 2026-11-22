import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/submissions/deliverable_body.dart';

void main() {
  test('reads the stored body back into prompt and answer pairs', () {
    const body =
        'Describe your print\nA phone stand in matte black.\n\n'
        'Why buy this colour again?\nA consistent colour across every batch.';
    expect(parseDeliverablePairs(body), const [
      DeliverablePair(
        prompt: 'Describe your print',
        answer: 'A phone stand in matte black.',
      ),
      DeliverablePair(
        prompt: 'Why buy this colour again?',
        answer: 'A consistent colour across every batch.',
      ),
    ]);
  });

  test('pairs flattened HTML paragraphs from the API', () {
    expect(
      parseDeliverablePairs(
        'List the three products\n\n'
        'Testing testing testing testing testing\n\n'
        'Explain what would help you decide\n\n'
        'Anyhow it goes.',
      ),
      const [
        DeliverablePair(
          prompt: 'List the three products',
          answer: 'Testing testing testing testing testing',
        ),
        DeliverablePair(
          prompt: 'Explain what would help you decide',
          answer: 'Anyhow it goes.',
        ),
      ],
    );
  });

  test('leaves a single free-text answer as one block', () {
    const body =
        'A WhatsApp catalogue plus a weekly hostel drop beats a website nobody visits.';
    expect(parseDeliverablePairs(body), const [
      DeliverablePair(prompt: null, answer: body),
    ]);
  });

  test('asks for See more when the prompt or answer is long', () {
    expect(
      needsSeeMore(
        const DeliverablePair(prompt: 'Short?', answer: 'A short answer here.'),
      ),
      isFalse,
    );
    expect(
      needsSeeMore(DeliverablePair(prompt: 'Short?', answer: 'x' * 200)),
      isTrue,
    );
  });
}

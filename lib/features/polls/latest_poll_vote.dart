import 'polls_state.dart';

/// One in-flight vote per poll. Later taps replace the waiting choice so
/// three quick changes send the last one, not all three.
class LatestPollVote {
  LatestPollVote(this._send, {this.delay = const Duration(milliseconds: 200)});

  final Future<VoteOutcome> Function(int choice) _send;
  final Duration delay;

  int? _wanted;
  Future<VoteOutcome>? _tail;

  Future<VoteOutcome> get done => _tail ?? Future.value(VoteOutcome.counted);

  Future<VoteOutcome> enqueue(int choice) {
    _wanted = choice;
    return _tail ??= _drain();
  }

  Future<VoteOutcome> _drain() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    var last = VoteOutcome.counted;
    try {
      while (_wanted != null) {
        final choice = _wanted!;
        _wanted = null;
        last = await _send(choice);
      }
      return last;
    } finally {
      _tail = null;
    }
  }
}

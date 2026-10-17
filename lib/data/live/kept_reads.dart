import 'dart:async';

import '../api_client.dart';

/// How long a read waits for the API while the phone holds a copy it can
/// show instead. A working connection answers well inside it, 3G included;
/// one that never answers would otherwise hold the screen on its skeleton
/// for the client's whole 20 s timeout.
const keptCopyWait = Duration(seconds: 3);

/// What [fetching] answers; or, when the phone holds a [kept] copy, that
/// copy once [fetching] fails without an answer to trust ([unanswered]) or
/// takes longer than [wait]. A fetch still out carries on, so its answer
/// is kept for the next read. Without a copy, [fetching] decides.
Future<T> orKept<T>(
  Future<T> fetching,
  Future<({T copy})?> kept, {
  Duration wait = keptCopyWait,
}) async {
  fetching.ignore();
  final ({T copy})? held;
  try {
    held = await kept;
  } on Object {
    return fetching;
  }
  if (held == null) return fetching;
  try {
    return await fetching.timeout(wait);
  } on TimeoutException {
    return held.copy;
  } on Object catch (error) {
    if (unanswered(error)) return held.copy;
    rethrow;
  }
}

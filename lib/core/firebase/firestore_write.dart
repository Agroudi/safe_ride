import 'dart:async';

import 'package:safe_ride/core/constants/app_constants.dart';

/// Waits for a Firestore write — but only [AppDurations.syncWait].
///
/// A write lands in the phone's cache at once and is queued for the server;
/// its future completes only when the server confirms it. Online that is
/// quick. Offline it would never come, so after the wait the write counts as
/// saved here and syncing later — the cache, and every screen reading it,
/// already shows it. A rejection that arrives in time is thrown as usual.
///
/// True when the server confirmed the write; false when it is saved on the
/// phone and still waiting — so a caller never says "saved" for what is only
/// queued.
Future<bool> settle(Future<void> write) async {
  try {
    await write.timeout(AppDurations.syncWait);
    return true;
  } on TimeoutException {
    // Pending: Firestore sends it when the connection returns.
    return false;
  }
}

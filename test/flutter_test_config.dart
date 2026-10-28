import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:safe_ride/core/platform/launch_handoff.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/halo_rings.dart';

/// Runs before every test file.
///
/// - The rings' loop never settles, so `pumpAndSettle` would time out on
///   every screen that shows them; `halo_rings_test` turns it back on.
/// - The splash intro starts at once instead of asking the platform for the
///   launch hand-off; `launch_handoff_test` turns that back on.
/// - Date symbols for every locale, as `main` loads them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HaloRings.ambient = false;
  LaunchHandoff.enabled = false;
  await initializeDateFormatting();
  await testMain();
}

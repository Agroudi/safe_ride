/// Where the app's public pages live. Build-time, like the map providers: a
/// test run points it at a local server.
abstract final class PublicLinks {
  static const String base = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://saferide-a9d9f.web.app',
  );
}

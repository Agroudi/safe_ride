import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safe_ride/core/constants/public_links.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_links.dart';

/// Proves an invite's link leads somewhere before anyone is given one.
abstract interface class ConnectionLinkCheck {
  /// Whether the invite page is there. Throws `ConnectionFailure` when that
  /// cannot be found out, which is a different thing from "no".
  Future<bool> pageReady();
}

class HttpConnectionLinkCheck implements ConnectionLinkCheck {
  const HttpConnectionLinkCheck(this._client);

  final http.Client _client;

  static const Duration _wait = Duration(seconds: 8);

  @override
  Future<bool> pageReady() async {
    try {
      final http.Response page = await _client
          .get(Uri.parse('${PublicLinks.base}${ConnectionLinks.path}'))
          .timeout(_wait);
      return page.statusCode == 200 &&
          utf8
              .decode(page.bodyBytes, allowMalformed: true)
              .contains(ConnectionLinks.pageMarker);
    } on Exception {
      throw const ConnectionFailure(ConnectionFailureCode.offline);
    }
  }
}

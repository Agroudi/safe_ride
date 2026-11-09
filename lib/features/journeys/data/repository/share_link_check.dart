import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:safe_ride/features/journeys/data/models/location_share.dart';

/// Proves a link works before anyone is given it, the way a recipient would
/// use it: the viewer page loads, and the share can be read with no account.
/// A link that "looks" fine but leads nowhere is worse than no link.
abstract interface class ShareLinkCheck {
  /// Whether the web viewer is there to open a link.
  Future<bool> viewerReady();

  /// Whether [token]'s share can be read by someone signed out.
  Future<bool> readable(String token);
}

class HttpShareLinkCheck implements ShareLinkCheck {
  const HttpShareLinkCheck(this._client);

  final http.Client _client;

  static const Duration _wait = Duration(seconds: 8);

  @override
  Future<bool> viewerReady() async {
    try {
      final http.Response page = await _client
          .get(Uri.parse('${ShareLinks.base}/s'))
          .timeout(_wait);
      return page.statusCode == 200 &&
          utf8
              .decode(page.bodyBytes, allowMalformed: true)
              .contains(ShareLinks.viewerMarker);
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> readable(String token) async {
    try {
      final http.Response share = await _client
          .get(Uri.parse('${ShareLinks.firestore}/shares/$token'))
          .timeout(_wait);
      return share.statusCode == 200;
    } on Exception {
      return false;
    }
  }
}

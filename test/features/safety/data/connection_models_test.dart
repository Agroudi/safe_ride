import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/public_links.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/features/safety/data/models/connection_access.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_links.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 5, 12);

  ConnectionModel connection({
    ConnectionStatus status = ConnectionStatus.accepted,
    bool alerts = false,
    String? nickname,
  }) => ConnectionModel(
    ownerUid: 'sara',
    contactUid: 'omar',
    contactName: 'Omar Ali',
    status: status,
    inviteId: 'x',
    createdAt: now,
    acceptedAt: now,
    permissions: ConnectionPermissions(safetyAlerts: alerts),
    nickname: nickname,
  );

  ConnectionInviteModel invite({
    required DateTime expiresAt,
    ConnectionStatus status = ConnectionStatus.pending,
  }) => ConnectionInviteModel(
    token: 't',
    inviterUid: 'sara',
    inviterName: 'Sara Ahmed',
    status: status,
    createdAt: now,
    expiresAt: expiresAt,
  );

  group('the state machine', () {
    test('a pending invite is accepted, expires or is cancelled', () {
      const ConnectionStatus from = ConnectionStatus.pending;
      expect(from.canMoveTo(ConnectionStatus.accepted), isTrue);
      expect(from.canMoveTo(ConnectionStatus.expired), isTrue);
      expect(from.canMoveTo(ConnectionStatus.revoked), isTrue);
      expect(from.canMoveTo(ConnectionStatus.pending), isFalse);
    });

    test('an accepted connection can only end', () {
      const ConnectionStatus from = ConnectionStatus.accepted;
      expect(from.canMoveTo(ConnectionStatus.revoked), isTrue);
      expect(from.canMoveTo(ConnectionStatus.pending), isFalse);
      expect(from.canMoveTo(ConnectionStatus.expired), isFalse);
      expect(from.canMoveTo(ConnectionStatus.accepted), isFalse);
    });

    test('revoked and expired go nowhere', () {
      for (final ConnectionStatus from in <ConnectionStatus>[
        ConnectionStatus.revoked,
        ConnectionStatus.expired,
      ]) {
        for (final ConnectionStatus to in ConnectionStatus.values) {
          expect(from.canMoveTo(to), isFalse, reason: '$from → $to');
        }
      }
    });
  });

  group('an invite', () {
    test('lasts three days', () {
      expect(ConnectionInviteModel.lifetime, const Duration(hours: 72));
    });

    test('is expired at its time, without anything written', () {
      final ConnectionInviteModel i = invite(expiresAt: now);
      expect(
        i.statusAt(now.subtract(const Duration(seconds: 1))),
        ConnectionStatus.pending,
      );
      expect(i.statusAt(now), ConnectionStatus.expired);
      expect(
        i.statusAt(now.add(const Duration(days: 1))),
        ConnectionStatus.expired,
      );
    });

    test('that was accepted stays accepted past its time', () {
      expect(
        invite(
          status: ConnectionStatus.accepted,
          expiresAt: now,
        ).statusAt(now.add(const Duration(days: 9))),
        ConnectionStatus.accepted,
      );
    });
  });

  group('a link', () {
    final String token = BearerToken.generate();

    test('carries the token after #, where no server sees it', () {
      final Uri uri = Uri.parse(ConnectionLinks.link(token));
      expect(uri.toString(), '${PublicLinks.base}/c#$token');
      expect(uri.path, '/c');
      expect(uri.query, isEmpty);
      expect(ConnectionLinks.tokenOf(uri), token);
    });

    test('with a malformed token has none', () {
      expect(ConnectionLinks.tokenOf(Uri.parse('https://x.y/c#short')), isNull);
      expect(ConnectionLinks.tokenOf(Uri.parse('https://x.y/c')), isNull);
    });

    test('is found in whatever was pasted', () {
      final String link = ConnectionLinks.link(token);
      expect(ConnectionLinks.tokenIn(link), token);
      expect(ConnectionLinks.tokenIn('  $token\n'), token);
      expect(
        ConnectionLinks.tokenIn('Sara invited you. Open this: $link'),
        token,
      );
    });

    test('nothing is taken for a token that is not one', () {
      expect(ConnectionLinks.tokenIn(''), isNull);
      expect(ConnectionLinks.tokenIn('hello there'), isNull);
      expect(ConnectionLinks.tokenIn(token.substring(1)), isNull);
      expect(ConnectionLinks.tokenIn('${token}a'), isNull);
    });
  });

  group('what a connection allows', () {
    const List<ConnectionAccessKind> never = <ConnectionAccessKind>[
      ConnectionAccessKind.liveLocation,
      ConnectionAccessKind.journeyHistory,
      ConnectionAccessKind.gpsHistory,
      ConnectionAccessKind.emergencyInformation,
    ];

    test('location and journeys are refused, whatever is stored', () {
      for (final ConnectionAccessKind kind in never) {
        expect(
          ConnectionAccess.allows(
            connection(alerts: true),
            kind,
            alertsBackend: true,
          ),
          isFalse,
          reason: kind.name,
        );
      }
    });

    test('alerts need all three: connected, allowed, and a backend', () {
      bool alerts(ConnectionModel c, {required bool backend}) =>
          ConnectionAccess.allows(
            c,
            ConnectionAccessKind.safetyAlerts,
            alertsBackend: backend,
          );

      expect(alerts(connection(alerts: true), backend: true), isTrue);
      expect(alerts(connection(alerts: true), backend: false), isFalse);
      expect(alerts(connection(), backend: true), isFalse);
      expect(
        alerts(
          connection(status: ConnectionStatus.revoked, alerts: true),
          backend: true,
        ),
        isFalse,
      );
    });

    test('this build has no alerts at all', () {
      expect(AppFeatures.contactAlerts, isFalse);
      expect(
        ConnectionAccess.allows(
          connection(alerts: true),
          ConnectionAccessKind.safetyAlerts,
        ),
        isFalse,
      );
    });
  });

  test('a nickname is what the owner reads; the name stays beneath it', () {
    expect(connection().displayName, 'Omar Ali');
    final ConnectionModel named = connection(nickname: 'Brother');
    expect(named.displayName, 'Brother');
    expect(named.contactName, 'Omar Ali');
  });
}

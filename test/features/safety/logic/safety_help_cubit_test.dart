import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/safety_help_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/safety_help_state.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';

import '../help_fakes.dart';

final DateTime _at = DateTime.utc(2026, 11, 8, 9);

ConnectionModel _connection(String uid, ConnectionStatus status) =>
    ConnectionModel(
      ownerUid: 'sara',
      contactUid: uid,
      contactName: 'Person $uid',
      status: status,
      inviteId: 'i-$uid',
      createdAt: _at,
      acceptedAt: _at,
    );

void main() {
  late FakeGate gate;
  late FakeConnections connections;
  late FakeContacts contacts;
  late RecordingDialer dialer;
  late RecordingComposer composer;
  late SafetyHelpCubit cubit;

  setUp(() {
    gate = FakeGate();
    connections = FakeConnections();
    contacts = FakeContacts();
    dialer = RecordingDialer();
    composer = RecordingComposer();
    cubit = SafetyHelpCubit(
      gate,
      connections,
      contacts,
      CallLauncher(dialer, composer),
    );
  });

  tearDown(() => cubit.close());

  group('the people it lists', () {
    test('nobody connected, nothing saved: an honest empty list', () async {
      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.connected, isEmpty);
      expect(cubit.state.saved, isEmpty);
    });

    test('only accepted connections; ended ones and invites are not people '
        'the user is connected to', () async {
      connections
        ..all = <ConnectionModel>[
          _connection('a', ConnectionStatus.accepted),
          _connection('b', ConnectionStatus.revoked),
        ]
        ..waiting = <ConnectionInviteModel>[
          ConnectionInviteModel(
            token: 't',
            inviterUid: 'sara',
            inviterName: 'Sara',
            status: ConnectionStatus.pending,
            createdAt: _at,
            expiresAt: _at.add(const Duration(days: 3)),
          ),
        ];
      await cubit.load();
      expect(cubit.state.connected, const <HelpConnection>[
        HelpConnection('Person a'),
      ]);
    });

    test('connections show a name and nothing else', () async {
      connections.all = <ConnectionModel>[
        _connection('a', ConnectionStatus.accepted).copyWith(nickname: 'Bro'),
      ];
      await cubit.load();
      expect(cubit.state.connected.single.name, 'Bro');
      expect(cubit.state.connected.single.props, <Object?>['Bro']);
    });

    test('saved numbers are listed without their numbers', () async {
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'c1',
          fullName: 'Mona Saleh',
          phone: '+966 55 111 2222',
          createdAt: _at,
          relationship: 'Sister',
        ),
      ];
      await cubit.load();
      final HelpSavedContact c = cubit.state.saved.single;
      expect(c.props, <Object?>[
        'c1',
        'Mona Saleh',
        'Sister',
        ContactReach.available,
      ]);
      expect(c.props.any((Object? p) => '$p'.contains('966')), isFalse);
    });

    test(
      'connections that cannot be read say so; saved numbers still show',
      () async {
        connections.failure = ConnectionFailureCode.offline;
        contacts.all = <TrustedContactModel>[
          TrustedContactModel(
            id: 'c1',
            fullName: 'Mona Saleh',
            phone: '+966551112222',
            createdAt: _at,
          ),
        ];
        await cubit.load();
        expect(cubit.state.connectionsFailed, isTrue);
        expect(cubit.state.saved, hasLength(1));
      },
    );
  });

  group('Call', () {
    setUp(() {
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'c1',
          fullName: 'Mona Saleh',
          phone: '+966551112222',
          createdAt: _at,
        ),
      ];
    });

    test('opens the phone app with that contact\'s number, and says only '
        'that', () async {
      await cubit.load();
      expect(await cubit.call('c1'), DialOutcome.opened);
      expect(dialer.opened, <String>['+966551112222']);
    });

    test('an unknown contact dials nothing', () async {
      await cubit.load();
      expect(await cubit.call('nobody'), DialOutcome.invalidNumber);
      expect(dialer.opened, isEmpty);
    });

    test('a phone that cannot dial is reported as such', () async {
      dialer.outcome = DialOutcome.noDialer;
      await cubit.load();
      expect(await cubit.call('c1'), DialOutcome.noDialer);
    });

    test('nothing is dialled by loading', () async {
      await cubit.load();
      expect(dialer.opened, isEmpty);
    });
  });

  group('an open escalation', () {
    final OpenEscalation open = OpenEscalation(
      checkId: 'e1-check',
      journeyId: 'j1',
      timedOutAt: _at,
    );

    test('is shown, and "I\'m okay" closes it once', () async {
      gate.open = open;
      await cubit.load();
      expect(cubit.state.escalation?.checkId, 'e1-check');

      gate.hold = Completer<void>();
      final Future<ResolveOutcome?> first = cubit.resolve();
      expect(cubit.state.resolving, isTrue);
      expect(await cubit.resolve(), isNull, reason: 'a second tap waits');
      gate.hold!.complete();
      expect(await first, ResolveOutcome.resolved);
      expect(gate.resolved, <String>['e1-check']);
      expect(cubit.state.escalation, isNull);
    });

    test('with none open, "I\'m okay" does nothing', () async {
      await cubit.load();
      expect(await cubit.resolve(), isNull);
      expect(gate.resolved, isEmpty);
    });
  });

  group('Batch 21: Message, and what can be reached', () {
    const String body =
        'I may need assistance. Please contact me as soon as possible.';

    test('Message opens the messaging app with the text exactly as given, '
        'never the number in the state', () async {
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'c1',
          fullName: 'Mona Saleh',
          phone: '+966 55-111 2222',
          createdAt: _at,
        ),
      ];
      await cubit.load();
      expect(await cubit.message('c1', body), ComposeOutcome.opened);
      expect(composer.composed, <(String, String)>[('+966551112222', body)]);
      expect(dialer.opened, isEmpty);
      expect(cubit.state.reaching, isNull);
    });

    test('an unknown contact is texted nothing', () async {
      await cubit.load();
      expect(await cubit.message('nobody', body), ComposeOutcome.invalidNumber);
      expect(composer.composed, isEmpty);
    });

    test('each saved number says whether it can be reached', () async {
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'ok',
          fullName: 'A',
          phone: '0550000001',
          createdAt: _at,
        ),
        TrustedContactModel(
          id: 'long',
          fullName: 'B',
          phone: '+966 55 000 0001 234 5',
          createdAt: _at,
        ),
        TrustedContactModel(
          id: 'none',
          fullName: 'C',
          phone: '',
          createdAt: _at,
        ),
      ];
      await cubit.load();
      expect(
        <String, ContactReach>{
          for (final HelpSavedContact c in cubit.state.saved) c.id: c.reach,
        },
        <String, ContactReach>{
          'ok': ContactReach.available,
          'long': ContactReach.invalid,
          'none': ContactReach.missing,
        },
      );
      expect(await cubit.call('long'), DialOutcome.invalidNumber);
      expect(dialer.opened, isEmpty);
    });

    test('loading opens nothing, and texting never closes an open '
        'escalation', () async {
      gate.open = OpenEscalation(
        checkId: 'e1-check',
        journeyId: 'j1',
        timedOutAt: _at,
      );
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'c1',
          fullName: 'Mona Saleh',
          phone: '0550000001',
          createdAt: _at,
        ),
      ];
      await cubit.load();
      expect(dialer.opened, isEmpty);
      expect(composer.composed, isEmpty);
      await cubit.message('c1', body);
      await cubit.call('c1');
      expect(gate.resolved, isEmpty);
      expect(cubit.state.escalation?.checkId, 'e1-check');
    });

    test('while an app is opening, a second tap is ignored', () async {
      contacts.all = <TrustedContactModel>[
        TrustedContactModel(
          id: 'c1',
          fullName: 'Mona Saleh',
          phone: '0550000001',
          createdAt: _at,
        ),
      ];
      await cubit.load();
      final Future<ComposeOutcome?> first = cubit.message('c1', body);
      expect(cubit.state.reaching, 'c1');
      expect(await cubit.call('c1'), isNull);
      expect(await first, ComposeOutcome.opened);
      expect(dialer.opened, isEmpty);
    });
  });
}

import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

enum ConnectionsPhase { loading, ready, failed }

final class ConnectionsState extends Equatable {
  const ConnectionsState({
    this.phase = ConnectionsPhase.loading,
    this.connected = const <ConnectionModel>[],
    this.ended = const <ConnectionModel>[],
    this.invites = const <ConnectionInviteModel>[],
    this.mayBeStale = false,
    this.busy = false,
    this.failure,
  });

  final ConnectionsPhase phase;
  final List<ConnectionModel> connected;
  final List<ConnectionModel> ended;

  /// Waiting or expired; a used one has become a connection.
  final List<ConnectionInviteModel> invites;

  /// What is shown is the phone's copy: the other side may have changed it.
  final bool mayBeStale;

  /// Something that needs the server is under way: one thing at a time.
  final bool busy;

  /// Why the list could not be read.
  final ConnectionFailureCode? failure;

  /// The connection with [contactUid], accepted or ended.
  ConnectionModel? find(String contactUid) {
    for (final ConnectionModel c in <ConnectionModel>[...connected, ...ended]) {
      if (c.contactUid == contactUid) return c;
    }
    return null;
  }

  ConnectionsState copyWith({bool? busy}) => ConnectionsState(
    phase: phase,
    connected: connected,
    ended: ended,
    invites: invites,
    mayBeStale: mayBeStale,
    busy: busy ?? this.busy,
    failure: failure,
  );

  @override
  List<Object?> get props => <Object?>[
    phase,
    connected,
    ended,
    invites,
    mayBeStale,
    busy,
    failure,
  ];
}

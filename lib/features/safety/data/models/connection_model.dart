import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/core/firebase/timestamp_converter.dart';

part 'connection_model.freezed.dart';
part 'connection_model.g.dart';

/// Where a relationship between two accounts stands. Pending and expired are
/// the invite's; accepted and revoked are the connection's. Coming back after
/// revoked is not a move: it takes a new invite, and starts a new connection.
enum ConnectionStatus {
  pending,
  accepted,
  revoked,
  expired;

  bool canMoveTo(ConnectionStatus next) => switch (this) {
    pending =>
      next == accepted || next == expired || next == ConnectionStatus.revoked,
    accepted => next == ConnectionStatus.revoked,
    revoked || expired => false,
  };
}

/// What a connection has been allowed to do. Stored so a later batch has a
/// place for it; the rules require it to be off, because no backend exists to
/// act on it. Location is not here on purpose: no connection can ever carry it.
@freezed
abstract class ConnectionPermissions with _$ConnectionPermissions {
  const factory ConnectionPermissions({@Default(false) bool safetyAlerts}) =
      _ConnectionPermissions;

  factory ConnectionPermissions.fromJson(Map<String, dynamic> json) =>
      _$ConnectionPermissionsFromJson(json);
}

/// One side of a connection, at `users/{ownerUid}/connections/{contactUid}`:
/// the other account as this one sees it. Each side has its own record, so a
/// nickname stays its owner's. `inviteId` is the same on both, and is what ties
/// the two together.
@freezed
abstract class ConnectionModel with _$ConnectionModel {
  const factory ConnectionModel({
    required String ownerUid,
    required String contactUid,

    /// Their name when they connected. It does not follow a later rename.
    required String contactName,
    required ConnectionStatus status,
    required String inviteId,

    /// When the invite was made. UTC.
    @TimestampConverter() required DateTime createdAt,

    /// The server's time of the acceptance. UTC.
    @TimestampConverter() required DateTime acceptedAt,
    @Default(ConnectionPermissions()) ConnectionPermissions permissions,

    /// The owner's own word for them; the other side never sees it.
    String? nickname,
    @NullableTimestampConverter() DateTime? revokedAt,

    /// Who ended it.
    String? revokedBy,
  }) = _ConnectionModel;

  const ConnectionModel._();

  factory ConnectionModel.fromJson(Map<String, dynamic> json) =>
      _$ConnectionModelFromJson(json);

  bool get isActive => status == ConnectionStatus.accepted;

  String get displayName => nickname ?? contactName;
}

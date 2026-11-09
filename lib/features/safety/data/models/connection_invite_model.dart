import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/core/firebase/timestamp_converter.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

part 'connection_invite_model.freezed.dart';
part 'connection_invite_model.g.dart';

/// An invitation to connect, at `connectionInvites/{token}`. The token is the
/// only way in, and it works once.
@freezed
abstract class ConnectionInviteModel with _$ConnectionInviteModel {
  const factory ConnectionInviteModel({
    required String token,
    required String inviterUid,

    /// Copied from the inviter's profile; the rules check that it is.
    required String inviterName,

    /// Only pending or accepted are stored: see [statusAt].
    required ConnectionStatus status,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime expiresAt,
    String? acceptedBy,
    @NullableTimestampConverter() DateTime? acceptedAt,
  }) = _ConnectionInviteModel;

  const ConnectionInviteModel._();

  factory ConnectionInviteModel.fromJson(Map<String, dynamic> json) =>
      _$ConnectionInviteModelFromJson(json);

  /// Three days: long enough to reach someone, short enough that a forgotten
  /// link stops working. The rules allow a little more, for a phone's clock.
  static const Duration lifetime = Duration(hours: 72);

  /// What it is at [now]. Expiring needs no write: a pending invite past its
  /// time simply is expired, and the rules refuse it by the server's clock.
  ConnectionStatus statusAt(DateTime now) =>
      status == ConnectionStatus.pending && !expiresAt.isAfter(now)
      ? ConnectionStatus.expired
      : status;
}

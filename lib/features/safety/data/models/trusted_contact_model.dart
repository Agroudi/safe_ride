import 'package:freezed_annotation/freezed_annotation.dart';

part 'trusted_contact_model.freezed.dart';
part 'trusted_contact_model.g.dart';

/// Someone the user trusts, kept on this phone. A record only: the number is
/// **never verified** and the contact is **never notified** — nothing in the
/// MVP calls, texts or shares with them.
@freezed
abstract class TrustedContactModel with _$TrustedContactModel {
  const factory TrustedContactModel({
    required String id,
    required String fullName,

    /// As typed; compared by its digits only.
    required String phone,

    /// UTC.
    required DateTime createdAt,

    /// "Sister", "Friend" — optional, the user's own word.
    String? relationship,
  }) = _TrustedContactModel;

  factory TrustedContactModel.fromJson(Map<String, dynamic> json) =>
      _$TrustedContactModelFromJson(json);
}

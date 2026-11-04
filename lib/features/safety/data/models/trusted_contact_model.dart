import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/core/firebase/timestamp_converter.dart';

part 'trusted_contact_model.freezed.dart';
part 'trusted_contact_model.g.dart';

/// Someone the user trusts, stored in their account
/// (`users/{uid}/contacts/{id}`). The number is **never verified**. Alerts
/// reach only a contact who accepted an invite in SafeRide (`contactLinks`);
/// nothing calls or texts them.
@freezed
abstract class TrustedContactModel with _$TrustedContactModel {
  const factory TrustedContactModel({
    required String id,
    required String fullName,

    /// As typed; compared by its digits only.
    required String phone,

    /// UTC; set by the server when the contact is saved.
    @TimestampConverter() required DateTime createdAt,

    /// "Sister", "Friend" — optional, the user's own word.
    String? relationship,
  }) = _TrustedContactModel;

  factory TrustedContactModel.fromJson(Map<String, dynamic> json) =>
      _$TrustedContactModelFromJson(json);
}

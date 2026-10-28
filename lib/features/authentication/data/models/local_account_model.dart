import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';

part 'local_account_model.freezed.dart';
part 'local_account_model.g.dart';

/// One demo account as `LocalAuthRepository` stores it on this device: the
/// user, and a salted PBKDF2 hash of the password — **never the password**.
@freezed
abstract class LocalAccountModel with _$LocalAccountModel {
  const factory LocalAccountModel({
    required UserModel user,

    /// Base64.
    required String salt,

    /// Base64 PBKDF2-HMAC-SHA256 of the password with [salt].
    required String hash,

    /// The rounds [hash] was made with, so raising the default later still
    /// verifies older accounts.
    required int iterations,
  }) = _LocalAccountModel;

  factory LocalAccountModel.fromJson(Map<String, dynamic> json) =>
      _$LocalAccountModelFromJson(json);
}

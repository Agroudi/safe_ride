import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// The signed-in person, as the app shows them. Holds nothing secret — the
/// password's hash lives only in `LocalAccountModel`, inside the repository.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String fullName,

    /// Trimmed and lower-cased: the account's key.
    required String email,
    required DateTime createdAt,

    /// Optional and **never verified** — no copy may say it is.
    String? phone,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

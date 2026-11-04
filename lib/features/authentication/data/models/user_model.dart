import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';

/// The signed-in person, as the app shows them. Holds nothing secret: the
/// password stays with Firebase Authentication. Email and creation time come
/// from the Auth account, name and phone from `users/{uid}`.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String fullName,

    /// Trimmed and lower-cased; it signs the user in and cannot be changed in
    /// the app.
    required String email,
    required DateTime createdAt,

    /// Optional and **never verified** — no copy may say it is.
    String? phone,
  }) = _UserModel;
}

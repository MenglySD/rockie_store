import 'package:rockie_store/models/json.dart';

/// Gender values accepted by the API, with labels shown in the app.
enum Gender {
  male('male', 'Male'),
  female('female', 'Female'),
  other('other', 'Other'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  final String value;
  final String label;
  const Gender(this.value, this.label);

  static Gender? fromValue(Object? value) {
    for (final gender in Gender.values) {
      if (gender.value == value) return gender;
    }
    return null;
  }
}

class User {
  final int id;
  final String name;
  final String? email;
  final Gender? gender;
  final String? phone;
  final String? avatarUrl;
  final bool hasPassword;
  final bool isSocialAccount;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.gender,
    this.phone,
    this.avatarUrl,
    this.hasPassword = true,
    this.isSocialAccount = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: asInt(json['id']),
    name: asString(json['name']),
    email: asStringOrNull(json['email']),
    gender: Gender.fromValue(json['gender']),
    phone: asStringOrNull(json['phone']),
    avatarUrl: asStringOrNull(json['avatar_url']),
    hasPassword: asBool(json['has_password'], true),
    isSocialAccount: asBool(json['is_social_account']),
    createdAt: asDate(json['created_at']),
  );
}

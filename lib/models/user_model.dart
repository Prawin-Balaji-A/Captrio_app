class UserModel {
  final String name;
  final String username;
  final String email;
  final String password;
  final String? pin;
  final String preferredLanguage;

  const UserModel({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.pin,
    required this.preferredLanguage,
  });

  factory UserModel.empty() => const UserModel(
    name:              '',
    username:          '',
    email:             '',
    password:          '',
    preferredLanguage: 'English',
  );

  UserModel copyWith({
    String? name,
    String? username,
    String? email,
    String? password,
    String? pin,
    String? preferredLanguage,
  }) {
    return UserModel(
      name:              name              ?? this.name,
      username:          username          ?? this.username,
      email:             email             ?? this.email,
      password:          password          ?? this.password,
      pin:               pin               ?? this.pin,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
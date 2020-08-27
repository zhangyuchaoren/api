class LoginResult {
  int userId;
  String token;

  LoginResult(this.userId, this.token);

  factory LoginResult.formMap(Map data) {
    return LoginResult(data["userId"], data["token"]);
  }
}

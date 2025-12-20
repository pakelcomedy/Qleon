class AuthService {
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
  }

  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoggedIn = true;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
  }
}

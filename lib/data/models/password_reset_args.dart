/// What the Enter code screen needs from the Forgot Password one.
class ResetCodeArgs {
  const ResetCodeArgs({required this.email, required this.expiresIn});

  final String email;

  /// Seconds the emailed code stays valid, as reported by the server.
  final int expiresIn;
}

/// What the Reset Password screen needs from the Enter code one.
class ResetPasswordArgs {
  const ResetPasswordArgs({required this.email, required this.resetToken});

  final String email;

  /// Proof that the emailed code was entered correctly; single-use.
  final String resetToken;
}

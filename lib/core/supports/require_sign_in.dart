import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_controller.dart';
import '../../views/widgets/profile/sign_in_sheet.dart';

/// Guests can browse everything except favoriting and account info. Runs
/// [action] if signed in; otherwise slides up the sign-in sheet.
void requireSignIn(BuildContext context, WidgetRef ref, VoidCallback action) {
  if (ref.read(authControllerProvider) != null) {
    action();
    return;
  }
  showSignInSheet(context);
}

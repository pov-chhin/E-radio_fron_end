import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../data/services/api_exception.dart';
import '../../../core/supports/mask_email.dart';
import '../../themes/light_theme.dart';
import '../../../data/repositories/password_reset_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../data/models/password_reset_args.dart';
import '../../widgets/password_reset/otp_field.dart';

/// Step 2: type the 6-digit code from the email. It's checked as soon as the
/// sixth digit lands; a wrong one clears the boxes. The code lasts as long as
/// the server said (two minutes), shown as a countdown, after which the boxes
/// lock until a new code is requested with Resend.
class EnterCodeView extends ConsumerStatefulWidget {
  const EnterCodeView({super.key, required this.args});

  final ResetCodeArgs args;

  @override
  ConsumerState<EnterCodeView> createState() => _EnterCodeViewState();
}

class _EnterCodeViewState extends ConsumerState<EnterCodeView> {
  static const _codeLength = 6;

  final _code = TextEditingController();
  Timer? _timer;
  late int _secondsLeft;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  bool get _expired => _secondsLeft <= 0;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.args.expiresIn);
    _code.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _secondsLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _onCodeChanged() {
    if (_code.text.length == _codeLength && !_verifying && !_expired) {
      _verify();
    }
  }

  String _messageFor(ApiException e, AppLocalizations l10n) {
    if (e.statusCode == 429) return l10n.pleaseWaitAndRetry;
    if (e.fieldError('code') != null) return l10n.invalidCode;
    return e.message;
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(passwordResetRepositoryProvider)
          .verifyCode(email: widget.args.email, code: _code.text);
      if (!mounted) return;
      _timer?.cancel();
      // The code is spent, so there's nothing to go back to here.
      context.pushReplacement(
        '/profile/forgot-password/reset',
        extra: ResetPasswordArgs(email: widget.args.email, resetToken: token),
      );
    } on ApiException catch (e) {
      _code.clear();
      setState(() => _error = _messageFor(e, l10n));
    } catch (error) {
      // No connection, a timeout, or a reply that isn't JSON — nothing the
      // server said. Without this the boxes just sat full and silent.
      debugPrint('Checking the reset code failed: $error');
      if (!mounted) return;
      _code.clear();
      setState(() => _error = l10n.couldntReachServer);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final expiresIn = await ref
          .read(passwordResetRepositoryProvider)
          .requestCode(widget.args.email);
      if (!mounted) return;
      _code.clear();
      _startCountdown(expiresIn);
      messenger.showSnackBar(SnackBar(content: Text(l10n.codeResent)));
    } on ApiException catch (e) {
      setState(() => _error = _messageFor(e, l10n));
    } catch (error) {
      debugPrint('Asking for a new reset code failed: $error');
      if (!mounted) return;
      setState(() => _error = l10n.couldntReachServer);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _countdown {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = Theme.of(context).colorScheme.error;

    // Part of the light-only auth flow (see the Sign In screen).
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          backgroundColor: AppColors.pageBackground,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 24,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.enterCode,
                              style: const TextStyle(
                                color: AppColors.lightInk,
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              l10n.codeSentTo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.lightInk,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              maskEmail(widget.args.email),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.lightInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 28),
                            OtpField(
                              controller: _code,
                              length: _codeLength,
                              // Not switched off while a code is being checked:
                              // a disabled field drops focus, and the keyboard
                              // with it, so the next try needed a tap first.
                              // _onCodeChanged already ignores input meanwhile.
                              enabled: !_expired,
                              hasError: _error != null,
                            ),
                            const SizedBox(height: 24),
                            if (_verifying)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            else
                              Text(
                                _expired
                                    ? l10n.codeExpired
                                    : l10n.codeExpiresIn(_countdown),
                                style: TextStyle(
                                  color: _expired ? error : AppColors.lightInk,
                                  fontSize: 14,
                                ),
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: error, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${l10n.didntGetCode} ',
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 14,
                      ),
                    ),
                    InkWell(
                      onTap: _resending ? null : _resend,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.resend,
                          style: TextStyle(
                            color: _resending
                                ? AppColors.slate400
                                : AppColors.slate500,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

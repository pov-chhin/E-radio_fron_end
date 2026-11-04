import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_colors.dart';
import '../../../data/services/api_exception.dart';
import '../../../core/supports/pick_profile_photo.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_text_field.dart';
import '../../widgets/profile/profile_avatar.dart';

/// Edit Profile: photo, name, phone and address. The email is shown but greyed
/// out — it's the account's identity, so it isn't editable here. (The design
/// also has city/country and social links; the API has no fields for those
/// yet, so they're left out.) The photo is picked from the gallery and
/// uploaded at once.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider);
    _firstName = TextEditingController(text: profile?.firstName);
    _lastName = TextEditingController(text: profile?.lastName);
    _email = TextEditingController(text: profile?.email);
    _phone = TextEditingController(text: profile?.phoneNumber);
    _address = TextEditingController(text: profile?.address);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      await pickProfilePhoto(context, ref);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accountInfoSaved)));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.fieldError('email') ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(authControllerProvider);
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfile),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.save,
                    style: const TextStyle(
                      color: AppColors.brand400,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Opacity(
                opacity: _uploadingPhoto ? 0.5 : 1,
                child: ProfileAvatar(
                  profile: profile,
                  size: 92,
                  onCameraTap: _changePhoto,
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _uploadingPhoto ? null : _changePhoto,
                child: Text(
                  l10n.changeProfilePhoto,
                  style: const TextStyle(
                    color: AppColors.brand400,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _firstName,
              label: l10n.firstName,
              validator: required,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _lastName,
              label: l10n.lastName,
              validator: required,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _email,
              label: l10n.emailAddress,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _phone,
              label: l10n.phoneNumber,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _address,
              label: l10n.address,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

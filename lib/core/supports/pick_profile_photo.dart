import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/api_exception.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers/auth_controller.dart';

/// Lets the user choose a photo from the gallery and uploads it as their
/// avatar, reporting the outcome in a snackbar. Returns true on success.
Future<bool> pickProfilePhoto(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(authControllerProvider.notifier);

  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return false;

  try {
    await controller.updateAvatar(picked.path);
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoUpdated)));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.fieldError('avatar') ?? l10n.photoUploadFailed)),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoUploadFailed)));
  }
  return false;
}

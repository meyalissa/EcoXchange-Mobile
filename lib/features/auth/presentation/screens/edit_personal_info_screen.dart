import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../data/profile_repository.dart';
import '../auth_provider.dart';
import '../providers/edit_personal_info_provider.dart';

/// EcoXchange Mobile — Edit Personal Information. ONE screen shared by both
/// Customer and Rider (see ProfileRepository's docblock: both edit the
/// exact same `users` row through the exact same backend endpoint, so a
/// second near-duplicate screen would be pure duplication, not a genuine
/// role difference). Never shows/edits rider_type, vehicle, vehicle
/// registration, recycling-centre assignment, coverage zone, working
/// radius, or rider status — those stay exclusively on the read-only
/// "Vehicle & Assignment" sheet (RiderProfileScreen), which this screen has
/// no connection to.
///
/// Callers pass in whatever they already have on screen (AuthProvider.user
/// for Customer, RiderProfileProvider.profile for Rider — two different
/// model shapes) as plain primitives, so this screen never needs to know
/// about either one.
class EditPersonalInfoScreen extends StatelessWidget {
  const EditPersonalInfoScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhoneNumber,
    required this.initialPhotoUrl,
  });

  final String initialName;
  final String initialEmail;
  final String? initialPhoneNumber;
  final String? initialPhotoUrl;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EditPersonalInfoProvider(
        context.read<ProfileRepository>(),
        context.read<AuthProvider>(),
        initialName: initialName,
        initialEmail: initialEmail,
        initialPhoneNumber: initialPhoneNumber,
        initialPhotoUrl: initialPhotoUrl,
      ),
      child: const _EditPersonalInfoView(),
    );
  }
}

class _EditPersonalInfoView extends StatefulWidget {
  const _EditPersonalInfoView();

  @override
  State<_EditPersonalInfoView> createState() => _EditPersonalInfoViewState();
}

class _EditPersonalInfoViewState extends State<_EditPersonalInfoView> {
  late final _nameController = TextEditingController(text: context.read<EditPersonalInfoProvider>().name);
  late final _emailController = TextEditingController(text: context.read<EditPersonalInfoProvider>().email);
  late final _phoneController = TextEditingController(text: context.read<EditPersonalInfoProvider>().phoneNumber);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    await context.read<EditPersonalInfoProvider>().pickAndUploadPhoto(source);

    if (!mounted) return;
    final error = context.read<EditPersonalInfoProvider>().photoError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: AppColors.red));
    }
  }

  Future<void> _save() async {
    final provider = context.read<EditPersonalInfoProvider>();
    provider.setName(_nameController.text);
    provider.setEmail(_emailController.text);
    provider.setPhoneNumber(_phoneController.text);

    final updated = await provider.save();
    if (!mounted) return;

    if (updated != null) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = provider.saveError;
    if (error != null) {
      final message = error is ValidationException ? (error.firstError ?? error.message) : error.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditPersonalInfoProvider>();

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Edit Personal Information'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _AvatarPicker(provider: provider, onTap: _pickPhoto)),
          const SizedBox(height: 28),
          const Text('Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n600)),
          const SizedBox(height: 6),
          AppTextField(key: const Key('edit-info-name'), controller: _nameController, hintText: 'Your full name', icon: Icons.person_outline),
          const SizedBox(height: 16),
          const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n600)),
          const SizedBox(height: 6),
          AppTextField(
            key: const Key('edit-info-email'),
            controller: _emailController,
            hintText: 'you@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          const Text('Phone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n600)),
          const SizedBox(height: 6),
          AppTextField(
            key: const Key('edit-info-phone'),
            controller: _phoneController,
            hintText: '+60123456780',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),
          EcoButton(
            key: const Key('edit-info-save'),
            label: 'Save Changes',
            pill: true,
            fullWidth: true,
            loading: provider.isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.provider, required this.onTap});

  final EditPersonalInfoProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pickedPath = provider.pickedImagePath;
    final photoUrl = provider.photoUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: const Key('edit-info-avatar'),
          width: 110,
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.green50,
            border: Border.all(color: AppColors.green200, width: 2),
          ),
          child: pickedPath != null
              ? Image.file(File(pickedPath), fit: BoxFit.cover)
              : (photoUrl != null
                  ? AppNetworkImage(
                      url: photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, _) => const Icon(Icons.person, size: 48, color: AppColors.green400),
                    )
                  : const Icon(Icons.person, size: 48, color: AppColors.green400)),
        ),
        if (provider.isUploadingPhoto)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white))),
            ),
          ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            key: const Key('edit-info-photo-button'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green500,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('edit-info-photo-camera'),
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green600),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              key: const Key('edit-info-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green600),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

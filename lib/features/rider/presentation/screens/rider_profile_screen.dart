import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../auth/presentation/screens/edit_personal_info_screen.dart';
import '../../data/models/rider_profile.dart';
import '../providers/rider_profile_provider.dart';
import 'rider_dashboard_screen.dart' show initialsOf;

/// EcoXchange Mobile — Rider Profile (05_rider_profile design):
/// `GET /rider/profile`. Identity, the server's own lifetime/this-month
/// totals, plus Log Out. Personal Information (name/email/phone/photo) is
/// editable via EditPersonalInfoScreen (shared with the Customer profile —
/// see that screen's docblock); "Vehicle & Assignment" stays strictly
/// read-only here (rider_type, vehicle, plate, recycling-centre assignment,
/// coverage zone, working radius, rider status are the Rider/Staff
/// management domain's own, separate concern — this screen never edits any
/// of them). Identity-document numbers are never shown (see RiderProfile).
/// Not shown because the backend has no support for them: ratings,
/// rankings, bank/payout details, and account deletion.
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RiderProfileProvider>();
      if (provider.profile == null && !provider.isLoading) provider.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderProfileProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<RiderProfile>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.profile,
        onRetry: provider.load,
        builder: (context, profile) => _ProfileContent(profile: profile),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final RiderProfile profile;

  void _showInfo(BuildContext context, String title, List<(String, String?)> rows) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.n800)),
              const SizedBox(height: 12),
              for (final (label, value) in rows) _Field(label: label, value: value),
            ],
          ),
        ),
      ),
    );
  }

  /// Personal Information only — a deliberately SEPARATE sheet from
  /// [_showInfo]'s generic one (used for "Vehicle & Assignment" below),
  /// since only this one ever gets an Edit action. Keeping them separate
  /// means there is no shared code path an edit button could accidentally
  /// end up attached to the read-only vehicle/assignment sheet through.
  void _showPersonalInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personal Information', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.n800)),
              const SizedBox(height: 12),
              _Field(label: 'Name', value: profile.name),
              _Field(label: 'Email', value: profile.email),
              _Field(label: 'Phone', value: profile.phoneNumber),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: EcoButton(
                  key: const Key('rider-profile-edit-personal-info'),
                  label: 'Edit Profile',
                  pill: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editPersonalInfo(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editPersonalInfo(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPersonalInfoScreen(
          initialName: profile.name,
          initialEmail: profile.email,
          initialPhoneNumber: profile.phoneNumber,
          initialPhotoUrl: profile.profilePhotoUrl,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      context.read<RiderProfileProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.'), backgroundColor: AppColors.green600));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = [profile.vehicleType, profile.vehiclePlateNo].whereType<String>().map(_humanise).join(' · ');
    final available = profile.riderStatus == 'available';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        GradientHeader(
          gradient: AppColors.homeHeroGradient,
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 26),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 3),
                        ),
                        child: profile.profilePhotoUrl != null
                            ? AppNetworkImage(
                                url: profile.profilePhotoUrl!,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (context, _, _) =>
                                    Text(initialsOf(profile.name), style: AppTheme.displayFont(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                              )
                            : Text(initialsOf(profile.name), style: AppTheme.displayFont(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      if (profile.riderStatus != null)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: available ? AppColors.green300 : AppColors.n300,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: AppTheme.headerIdentityName()),
                        const SizedBox(height: 2),
                        Text(profile.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        if (vehicle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(vehicle, key: const Key('rider-profile-vehicle'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                        if (profile.riderStatus != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.rFull)),
                            child: Text(
                              '● ${_humanise(profile.riderStatus!)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                key: const Key('rider-profile-stats'),
                children: [
                  _Stat(value: '${profile.totalCompleted}', label: 'Collections'),
                  const SizedBox(width: 10),
                  _Stat(value: '${profile.totalWeightKg.toStringAsFixed(1)} kg', label: 'Collected'),
                  const SizedBox(width: 10),
                  _Stat(value: '${profile.completedThisMonth}', label: 'This Month'),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Text('ACCOUNT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.6)),
        ),
        _MenuCard(
          children: [
            _MenuRow(
              key: const Key('rider-profile-personal'),
              icon: Icons.person_outline,
              title: 'Personal Information',
              subtitle: 'Name, email, phone',
              onTap: () => _showPersonalInfo(context),
            ),
            _MenuRow(
              key: const Key('rider-profile-vehicle-info'),
              icon: Icons.two_wheeler_outlined,
              title: 'Vehicle & Assignment',
              subtitle: 'Rider type, centre, coverage',
              onTap: () => _showInfo(context, 'Vehicle & Assignment', [
                ('Rider type', profile.riderType == null ? null : _humanise(profile.riderType!)),
                ('Vehicle', vehicle.isEmpty ? null : vehicle),
                ('Recycling centre', profile.centreName),
                ('Coverage zone', profile.coverageZone),
                ('Working radius', profile.workingRadiusKm == null ? null : '${profile.workingRadiusKm!.toStringAsFixed(1)} km'),
              ]),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: SizedBox(
            height: 56,
            child: TextButton.icon(
              key: const Key('rider-logout'),
              onPressed: () => context.read<AuthProvider>().logout(),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.redLight,
                foregroundColor: AppColors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ),
        ),
      ],
    );
  }
}

String _humanise(String value) {
  final words = value.replaceAll('_', ' ').trim();
  return words.isEmpty ? value : words[0].toUpperCase() + words.substring(1);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.r16)),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20), boxShadow: AppShadows.sh1),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.n100),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.n50, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: Icon(icon, color: AppColors.green600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.displayFont(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.n500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.n300),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.n500))),
          Text(value ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800)),
        ],
      ),
    );
  }
}

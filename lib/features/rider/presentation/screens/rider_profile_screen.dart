import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/rider_profile.dart';
import '../providers/rider_profile_provider.dart';

/// EcoXchange Mobile — Rider Profile (Phase R1, read-only):
/// `GET /rider/profile`. Identity, vehicle, assignment and the server's own
/// lifetime/this-month totals. Identity-document numbers are never shown
/// (see RiderProfile).
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RiderProfileProvider>().load());
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

  @override
  Widget build(BuildContext context) {
    final vehicle = [profile.vehicleType, profile.vehiclePlateNo].whereType<String>().map(_humanise).join(' · ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        EcoCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.green50,
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.n800)),
                    Text(profile.email, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                    if (profile.phoneNumber != null) Text(profile.phoneNumber!, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(label: 'Completed', value: '${profile.totalCompleted}'),
            const SizedBox(width: 10),
            _Stat(label: 'This month', value: '${profile.completedThisMonth}'),
            const SizedBox(width: 10),
            _Stat(label: 'Collected', value: '${profile.totalWeightKg.toStringAsFixed(1)} kg'),
          ],
        ),
        const SizedBox(height: 12),
        EcoCard(
          child: Column(
            children: [
              _Field(label: 'Status', value: profile.riderStatus == null ? null : _humanise(profile.riderStatus!)),
              _Field(label: 'Rider type', value: profile.riderType == null ? null : _humanise(profile.riderType!)),
              _Field(label: 'Vehicle', value: vehicle.isEmpty ? null : vehicle),
              _Field(label: 'Recycling centre', value: profile.centreName),
              _Field(label: 'Coverage zone', value: profile.coverageZone),
              _Field(
                label: 'Working radius',
                value: profile.workingRadiusKm == null ? null : '${profile.workingRadiusKm!.toStringAsFixed(1)} km',
              ),
            ],
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
      child: EcoCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.green700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
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

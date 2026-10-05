import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/models/address.dart';
import '../../data/repositories/customer_address_repository.dart';
import '../providers/dashboard_provider.dart';
import '../providers/item_catalogue_provider.dart';
import '../providers/recycling_centre_list_provider.dart';
import 'booking/add_address_screen.dart';
import 'item_list_screen.dart';
import 'recycling_centre_list_screen.dart';

/// EcoXchange Mobile — Customer Profile (05_customer_profile design).
/// Identity from the logged-in user (`/auth/me`), statistics from
/// `GET /customer/dashboard`, saved addresses from the real address API.
/// Not shown because the backend has no support for them: points, a
/// membership tier, bank/payout details, profile editing and account
/// deletion (no buttons that would only pretend to work).
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboard = context.read<DashboardProvider>();
      if (dashboard.data == null && !dashboard.isLoading) dashboard.load();
    });
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Shell-scoped providers are handed to pushed routes explicitly.
  void _openCentres() {
    final provider = context.read<RecyclingCentreListProvider>();
    _push(ChangeNotifierProvider.value(
      value: provider,
      child: const Scaffold(backgroundColor: AppColors.n50, appBar: EcoAppBar(title: 'Recycling Centres'), body: RecyclingCentreListScreen()),
    ));
  }

  void _openItems() {
    final provider = context.read<ItemCatalogueProvider>();
    _push(ChangeNotifierProvider.value(
      value: provider,
      child: const Scaffold(backgroundColor: AppColors.n50, appBar: EcoAppBar(title: 'Items Guide'), body: ItemListScreen()),
    ));
  }

  void _showPersonalInfo(UserModel user) {
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
              _InfoLine(label: 'Name', value: user.name),
              _InfoLine(label: 'Email', value: user.email),
              _InfoLine(label: 'Phone', value: user.phoneNumber ?? '—'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = context.watch<DashboardProvider>().data;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        GradientHeader(
          gradient: AppColors.homeHeroGradient,
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 26),
          child: Column(
            children: [
              Row(
                children: [
                  _ProfileAvatar(initials: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTheme.headerIdentityName()),
                        const SizedBox(height: 4),
                        Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        if (user.phoneNumber != null) Text(user.phoneNumber!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                key: const Key('profile-stats'),
                children: [
                  _StatBox(value: stats == null ? '—' : '${stats.totalPickups}', label: 'Pickups'),
                  const SizedBox(width: 10),
                  _StatBox(value: stats == null ? '—' : '${stats.totalWeightKg.toStringAsFixed(1)} kg', label: 'Recycled'),
                  const SizedBox(width: 10),
                  _StatBox(value: stats == null ? '—' : 'RM ${stats.totalRewardsEarned.toStringAsFixed(2)}', label: 'Earned'),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Text('ACCOUNT SETTINGS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.6)),
        ),
        _MenuCard(
          children: [
            _MenuRow(icon: Icons.person_outline, title: 'Personal Information', subtitle: 'Name, email, phone', onTap: () => _showPersonalInfo(user)),
            _MenuRow(icon: Icons.location_on_outlined, title: 'Saved Addresses', subtitle: 'Your pickup addresses', onTap: () => _push(const SavedAddressesScreen())),
            _MenuRow(icon: Icons.storefront_outlined, title: 'Recycling Centres', subtitle: 'Centres near you', onTap: _openCentres),
            _MenuRow(icon: Icons.recycling_outlined, title: 'Items Guide', subtitle: 'What you can recycle', onTap: _openItems),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: SizedBox(
            height: 56,
            child: TextButton.icon(
              key: const Key('profile-logout'),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 3),
      ),
      child: Text(initials, style: AppTheme.displayFont(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

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
  const _MenuRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: AppColors.n500))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.n800))),
        ],
      ),
    );
  }
}

/// The customer's saved addresses (`GET /customer/addresses`), with the
/// existing Add Address flow. Read + add only from here.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<AddressModel>? _addresses;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<CustomerAddressRepository>().getAddresses();
      if (!mounted) return;
      setState(() => _addresses = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<AddressModel>(MaterialPageRoute(builder: (_) => const AddAddressScreen()));
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(
        title: 'Saved Addresses',
        actions: [IconButton(key: const Key('address-add'), tooltip: 'Add address', icon: const Icon(Icons.add), onPressed: _add)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView<List<AddressModel>>(
          isLoading: _loading,
          error: _error,
          data: _addresses,
          isEmpty: _addresses?.isEmpty ?? true,
          emptyMessage: 'No saved addresses yet. Tap + to add one.',
          emptyIcon: Icons.location_off_outlined,
          onRetry: _load,
          builder: (context, list) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = list[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r16), boxShadow: AppShadows.sh1),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.green600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a.displayLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.n800)),
                              if (a.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                                  child: const Text('DEFAULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green600)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(a.formatted, style: const TextStyle(fontSize: 13, color: AppColors.n600, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

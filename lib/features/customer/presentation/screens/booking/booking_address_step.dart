import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/async_state_view.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/address.dart';
import '../../providers/pickup_booking_provider.dart';
import 'add_address_screen.dart';

/// EcoXchange Mobile — Pickup Booking Step 2 (Stage 3). Real saved
/// addresses only (`GET /customer/addresses`) — no GPS/map picker (the
/// backend already resolves coordinates from the address text via
/// `GeocodingService`; see `CustomerAddressRepository`'s docblock), no
/// fabricated "current location" card the approved design's `book-
/// pickup.html` shows (that requires device GPS this stage doesn't add).
class BookingAddressStep extends StatefulWidget {
  const BookingAddressStep({super.key, required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<BookingAddressStep> createState() => _BookingAddressStepState();
}

class _BookingAddressStepState extends State<BookingAddressStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PickupBookingProvider>().loadAddresses());
  }

  Future<void> _addAddress() async {
    final newAddress = await Navigator.of(context).push<AddressModel>(
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (newAddress != null && mounted) {
      context.read<PickupBookingProvider>().addAddressAndSelect(newAddress);
      if (!newAddress.hasCoordinates) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Address saved, but location could not be detected. Edit the address or try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();

    return Column(
      children: [
        Expanded(
          child: AsyncStateView<List<AddressModel>>(
            isLoading: booking.isLoadingAddresses,
            error: booking.addressesError,
            data: booking.addresses,
            isEmpty: booking.addresses.isEmpty,
            emptyMessage: 'No saved addresses yet. Add one to continue.',
            emptyIcon: Icons.location_on_outlined,
            onRetry: () => context.read<PickupBookingProvider>().loadAddresses(),
            builder: (context, addresses) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Where should the rider collect your recyclables?', style: TextStyle(fontSize: 13, color: AppColors.n500)),
                const SizedBox(height: 14),
                for (final address in addresses) ...[
                  _AddressCard(address: address, selected: booking.selectedAddress?.id == address.id, onTap: () => booking.selectAddress(address)),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _addAddress,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add New Address'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.n500,
                    side: const BorderSide(color: AppColors.n200, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r16)),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
          child: Row(
            children: [
              Expanded(child: EcoButton(label: '← Back', variant: EcoButtonVariant.outline, pill: true, fullWidth: true, onPressed: widget.onBack)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EcoButton(label: 'Continue →', pill: true, fullWidth: true, onPressed: booking.canProceedFromAddress ? widget.onNext : null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.selected, required this.onTap});

  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.r16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.green50 : AppColors.n0,
            borderRadius: BorderRadius.circular(AppRadii.r16),
            border: Border.all(color: selected ? AppColors.green400 : AppColors.n100, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: selected ? AppColors.green500 : AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
                child: Icon(Icons.home_outlined, color: selected ? Colors.white : AppColors.n500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(address.displayLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? AppColors.green700 : AppColors.n800)),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                            child: const Text('DEFAULT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF7B4F00))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(address.formatted, style: TextStyle(fontSize: 12, color: selected ? AppColors.green600 : AppColors.n500)),
                    if (!address.hasCoordinates) ...[
                      const SizedBox(height: 3),
                      const Text('No location detected yet', style: TextStyle(fontSize: 11, color: AppColors.red)),
                    ],
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.green500 : AppColors.n200),
                child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

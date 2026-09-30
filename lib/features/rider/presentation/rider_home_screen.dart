import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/auth_provider.dart';

/// EcoXchange Mobile — Rider application foundation (Phase 4C.1).
/// See CustomerHomeScreen's docblock — same purpose, rider side.
class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final riderStatus = user.riderProfile?.riderStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoXchange Rider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE8F5E2),
                child: Icon(Icons.pedal_bike, size: 36, color: Color(0xFF136B40)),
              ),
              const SizedBox(height: 16),
              Text('Welcome, ${user.name}', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Rider Dashboard', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in as', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(user.email),
                      if (riderStatus != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: riderStatus == 'available' ? Colors.green : Colors.grey),
                            const SizedBox(width: 6),
                            Text('Status: $riderStatus'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Foundation phase — assigned pickups and actions arrive in a later phase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

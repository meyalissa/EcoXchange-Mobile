import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/repositories/rider_pickup_repository.dart';
import '../providers/rider_pickup_detail_provider.dart';
import '../screens/rider_complete_pickup_screen.dart';

/// EcoXchange Mobile — the ONE way any rider screen performs a pickup action
/// (detail screen, Home's active job, My Tasks, Route). It always goes
/// through [RiderPickupDetailProvider] (the server-confirmed state machine:
/// only the next action, no double submission, 409 re-read), with a
/// confirmation first; `complete` opens [RiderCompletePickupScreen].

/// Wording per action. Success text matches the API's own messages.
({String button, IconData icon, String title, String body, String done}) riderActionCopy(RiderPickupAction action) {
  return switch (action) {
    RiderPickupAction.accept => (
        button: 'Accept Pickup',
        icon: Icons.check_circle_outline,
        title: 'Accept this pickup?',
        body: 'It will be added to your jobs and the customer will see it has been accepted.',
        done: 'Pickup accepted.',
      ),
    RiderPickupAction.start => (
        button: 'Start Pickup',
        icon: Icons.two_wheeler_outlined,
        title: 'Start this pickup?',
        body: 'This marks you as on the way to the pickup address.',
        done: 'On the way.',
      ),
    RiderPickupAction.collect => (
        button: 'Collect Pickup',
        icon: Icons.inventory_2_outlined,
        title: 'Start collecting?',
        body: 'Confirm you have arrived at the pickup address and are collecting the items.',
        done: 'Collection started.',
      ),
    RiderPickupAction.complete => (
        button: 'Complete Pickup',
        icon: Icons.task_alt,
        title: 'Complete this pickup?',
        body: '',
        done: 'Pickup completed.',
      ),
  };
}

/// The real server message, with friendlier wording only for transport
/// failures (same rule as the shared AsyncStateView).
String riderActionErrorText(ApiException e) {
  final base = switch (e) {
    NetworkException() => 'Unable to connect. Check your internet connection.',
    TimeoutApiException() => 'The connection timed out. Please try again.',
    ValidationException() => e.firstError ?? e.message,
    _ => e.message,
  };
  final conflict = e is ServerException && e.statusCode == 409;
  return conflict ? '$base The pickup has been refreshed to show its current status.' : base;
}

/// Confirms and performs [action] on [provider] (or opens the completion
/// screen for `complete`). Returns true only when Laravel confirmed it; a
/// success snackbar is shown then. Errors stay in [RiderPickupDetailProvider.actionError].
Future<bool> runRiderAction(BuildContext context, RiderPickupDetailProvider provider, RiderPickupAction action) async {
  if (provider.isSubmitting || provider.pickup == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final copy = riderActionCopy(action);

  if (action == RiderPickupAction.complete) {
    provider.clearActionError();
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: provider, child: const RiderCompletePickupScreen())),
    );
    if (completed == true) messenger.showSnackBar(SnackBar(content: Text(copy.done)));
    return completed == true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(copy.title),
      content: Text('${provider.pickup!.reference} — ${copy.body}'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(
          key: const Key('rider-action-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(copy.button),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final ok = await switch (action) {
    RiderPickupAction.accept => provider.accept(),
    RiderPickupAction.start => provider.start(),
    RiderPickupAction.collect => provider.collect(),
    RiderPickupAction.complete => Future.value(false),
  };
  if (ok) messenger.showSnackBar(SnackBar(content: Text(copy.done)));
  return ok;
}

/// From a card (Home, My Tasks): loads that pickup's provider and runs its
/// single next action through [runRiderAction]. [expected], when given, must
/// match the server's current next action (e.g. "Accept Task") — otherwise
/// nothing is sent and the rider is told the pickup has changed. Problems
/// are shown as snackbars. Returns true when an action was confirmed.
Future<bool> runNextActionForPickup(BuildContext context, int pickupId, {RiderPickupAction? expected}) async {
  final messenger = ScaffoldMessenger.of(context);
  final provider = RiderPickupDetailProvider(context.read<RiderPickupRepository>(), pickupId);
  try {
    await provider.load();
    if (provider.loadError != null) {
      messenger.showSnackBar(SnackBar(content: Text(riderActionErrorText(provider.loadError!))));
      return false;
    }
    final next = provider.nextAction;
    if (next == null || (expected != null && next != expected)) {
      messenger.showSnackBar(const SnackBar(content: Text('This pickup has changed. Its list has been refreshed.')));
      return true; // so the caller refreshes its list
    }
    if (!context.mounted) return false;
    final ok = await runRiderAction(context, provider, next);
    if (!ok && provider.actionError != null) {
      messenger.showSnackBar(SnackBar(content: Text(riderActionErrorText(provider.actionError!))));
    }
    return ok || provider.actionError is ServerException;
  } finally {
    provider.dispose();
  }
}

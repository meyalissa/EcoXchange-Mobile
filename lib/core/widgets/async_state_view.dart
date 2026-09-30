import 'package:flutter/material.dart';

import '../api/api_exception.dart';

/// EcoXchange Mobile — the one shared loading/empty/error scaffold every
/// network-backed customer screen uses (Phase 4C.2 §14). Centralising this
/// means no screen leaves a blank white page, silently swallows a failure,
/// or shows a raw Dio/exception message to the user.
///
/// Usage: pass whatever `AsyncSnapshot`-like trio applies —
/// [isLoading]/[error]/[isEmpty] — and this picks the right state. The
/// happy-path content comes from [builder], only ever called when there is
/// real data to show.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.data,
    required this.builder,
    this.isEmpty = false,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry,
  });

  final bool isLoading;
  final ApiException? error;
  final T? data;
  final Widget Function(BuildContext context, T data) builder;
  final bool isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && data == null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        message: _friendlyErrorMessage(error!),
        onRetry: onRetry,
      );
    }

    if (data == null || isEmpty) {
      return _MessageState(icon: emptyIcon, message: emptyMessage, onRetry: onRetry, isError: false);
    }

    return builder(context, data as T);
  }

  /// Every message here comes from the real ApiException — see
  /// api_exception.dart. This only chooses tone/prefix, never invents a
  /// different underlying reason than what the server/transport reported.
  static String _friendlyErrorMessage(ApiException error) {
    return switch (error) {
      NetworkException() => 'Unable to connect. Check your internet connection.',
      TimeoutApiException() => 'The connection timed out. Please try again.',
      ForbiddenException() => error.message,
      ValidationException() => error.firstError ?? error.message,
      _ => error.message,
    };
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.onRetry,
    this.isError = true,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: isError ? Colors.black38 : Colors.black26),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ],
        ),
      ),
    );
  }
}

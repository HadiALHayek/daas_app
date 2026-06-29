import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

/// Tracks user activity and re-validates the session when the app resumes.
class SessionScope extends ConsumerStatefulWidget {
  const SessionScope({
    super.key,
    required this.child,
    required this.router,
  });

  final Widget child;
  final GoRouter router;

  @override
  ConsumerState<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends ConsumerState<SessionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateSession();
    }
  }

  Future<void> _validateSession() async {
    final client = ref.read(apiClientProvider);
    final valid = await client.hasValidSession();
    if (!valid && mounted) {
      ref.read(sessionRefreshProvider).value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

final sessionRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier(0);
  ref.onDispose(notifier.dispose);
  return notifier;
});

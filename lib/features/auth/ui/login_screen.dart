import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../app/sync_provider.dart';
import '../auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  bool _loginPassVisible = false;
  bool _regPassVisible = false;
  bool _regConfirmVisible = false;

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    // Pop screen as soon as a valid session is established (login or register)
    ref.listen(authStateProvider, (_, next) {
      next.whenData((event) {
        if (event.event == AuthChangeEvent.signedIn && mounted) {
          Navigator.pop(context);
        }
      });
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Cloud Account',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_outlined,
                      color: AppTheme.primary, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sync your store data',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Back up your products, sales, and customers. Access from any device.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Register'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LoginTab(
                  emailCtrl: _loginEmailCtrl,
                  passCtrl: _loginPassCtrl,
                  passVisible: _loginPassVisible,
                  onTogglePass: () =>
                      setState(() => _loginPassVisible = !_loginPassVisible),
                  isLoading: isLoading,
                  onSubmit: _doLogin,
                ),
                _RegisterTab(
                  emailCtrl: _regEmailCtrl,
                  passCtrl: _regPassCtrl,
                  confirmCtrl: _regConfirmCtrl,
                  passVisible: _regPassVisible,
                  confirmVisible: _regConfirmVisible,
                  onTogglePass: () =>
                      setState(() => _regPassVisible = !_regPassVisible),
                  onToggleConfirm: () =>
                      setState(() => _regConfirmVisible = !_regConfirmVisible),
                  isLoading: isLoading,
                  onSubmit: _doRegister,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doLogin() async {
    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    // Navigator.pop is handled by authStateProvider listener on signedIn
    final error = await ref.read(authNotifierProvider.notifier).signIn(
          email: email,
          password: pass,
          onSuccess: () => ref.read(syncNotifierProvider.notifier).sync(),
        );
    if (error != null && mounted) _showError(error);
  }

  Future<void> _doRegister() async {
    final email = _regEmailCtrl.text.trim();
    final pass = _regPassCtrl.text;
    final confirm = _regConfirmCtrl.text;
    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (pass != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    // onSuccess fires if email confirmation is disabled (session returned immediately)
    final error = await ref.read(authNotifierProvider.notifier).signUp(
          email: email,
          password: pass,
          onSuccess: () => ref.read(syncNotifierProvider.notifier).sync(),
        );
    if (error != null && mounted) _showError(error);
    // If no session (email confirmation still on), nothing happens — Supabase dashboard fix needed
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ── Login Tab ────────────────────────────────────────────────

class _LoginTab extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool passVisible;
  final VoidCallback onTogglePass;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _LoginTab({
    required this.emailCtrl,
    required this.passCtrl,
    required this.passVisible,
    required this.onTogglePass,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _FieldLabel('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'you@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: passCtrl,
            obscureText: !passVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    passVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: onTogglePass,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Login',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Register Tab ─────────────────────────────────────────────

class _RegisterTab extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool passVisible;
  final bool confirmVisible;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _RegisterTab({
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.passVisible,
    required this.confirmVisible,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _FieldLabel('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'you@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          const SizedBox(height: 6),
          TextField(
            controller: passCtrl,
            obscureText: !passVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    passVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: onTogglePass,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Confirm Password'),
          const SizedBox(height: 6),
          TextField(
            controller: confirmCtrl,
            obscureText: !confirmVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Re-enter password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(confirmVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: onToggleConfirm,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cloud sync is a premium feature. Register now to create your account — you can activate sync later.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary));
  }
}

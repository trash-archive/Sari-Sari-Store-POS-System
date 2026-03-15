import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../auth_provider.dart';

// ── Contact details — update these before release ────────────
const _devEmail = 'htordios@gmail.com';
const _devWhatsApp = '+639XXXXXXXXX'; // replace with your number
const _premiumPrice = '₱299'; // one-time payment placeholder
// ─────────────────────────────────────────────────────────────

class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Upgrade to Premium',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero banner
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D5F3F), Color(0xFF4A8B5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TindaKo Premium',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One-time payment. Lifetime access.',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _premiumPrice,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features list
            _sectionCard(
              title: 'What you get',
              child: Column(
                children: const [
                  _FeatureTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Cloud Backup',
                    subtitle:
                        'Your products, sales, and customers are safely backed up online.',
                  ),
                  _FeatureTile(
                    icon: Icons.devices_outlined,
                    title: 'Multi-Device Access',
                    subtitle:
                        'Use TindaKo on any Android device with the same account.',
                  ),
                  _FeatureTile(
                    icon: Icons.people_outline,
                    title: 'Tindera Sharing',
                    subtitle:
                        'Give your tinderas access to the same store data.',
                  ),
                  _FeatureTile(
                    icon: Icons.sync_outlined,
                    title: 'Auto Sync',
                    subtitle:
                        'Data syncs automatically after every sale — no manual steps.',
                  ),
                  _FeatureTile(
                    icon: Icons.restore_outlined,
                    title: 'Data Recovery',
                    subtitle:
                        'Lost or broken phone? Restore all your data on a new device.',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // How to pay
            _sectionCard(
              title: 'How to activate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepTile(
                      step: '1',
                      text: 'Send $_premiumPrice via GCash or bank transfer.'),
                  _StepTile(
                      step: '2',
                      text:
                          'Message the developer with your payment screenshot and the email below.'),
                  _StepTile(
                      step: '3',
                      text:
                          'Your account will be activated within 24 hours.',
                      isLast: true),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your account: ${user?.email ?? '—'}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CTA buttons
            ElevatedButton.icon(
              onPressed: () => _contact(
                  'mailto:$_devEmail?subject=TindaKo%20Premium%20Activation&body=Hi%2C%20I%20would%20like%20to%20activate%20premium%20for%20my%20account%3A%20${user?.email ?? ''}'),
              icon: const Icon(Icons.email_outlined, size: 20),
              label: const Text('Email Developer',
                  style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _contact(
                  'https://wa.me/${_devWhatsApp.replaceAll('+', '')}?text=Hi%2C%20I%20want%20to%20activate%20TindaKo%20Premium%20for%20${user?.email ?? ''}'),
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: const Text('WhatsApp Developer',
                  style: TextStyle(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _contact(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ── Feature tile ─────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 18),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}

// ── Step tile ────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final String step;
  final String text;
  final bool isLast;

  const _StepTile(
      {required this.step, required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700)),
            ),
          ),
        ],
      ),
    );
  }
}

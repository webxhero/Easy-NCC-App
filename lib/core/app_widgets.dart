import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 42, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.asset(
            'assets/branding/bncc_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: AppColors.green,
              alignment: Alignment.center,
              child: const Icon(Icons.shield_outlined, color: Colors.white),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Easy NCC', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.greenDark,
              )),
              Text('CADET MANAGEMENT', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1, color: AppColors.muted, fontWeight: FontWeight.w700,
              )),
            ],
          ),
        ],
      ],
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.greenDark, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          ])),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.tint = AppColors.green});
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: tint.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.greenDark)),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ])),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: AppColors.greenLight),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.danger),
        const SizedBox(height: 12),
        const Text('তথ্য লোড করা যায়নি', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('$error', textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('আবার চেষ্টা করুন')),
        ],
      ]),
    ));
  }
}

String formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return 'তারিখ নেই';
  try {
    final date = DateTime.parse(value.toString()).toLocal();
    return DateFormat('dd MMM yyyy').format(date);
  } catch (_) {
    return value.toString();
  }
}

String formatDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return 'সময় নেই';
  try {
    final date = DateTime.parse(value.toString()).toLocal();
    return DateFormat('dd MMM yyyy • hh:mm a').format(date);
  } catch (_) {
    return value.toString();
  }
}

bool isAdmin(Map<String, dynamic> profile) => profile['role'] == 'admin';
bool isSupervisor(Map<String, dynamic> profile) => profile['role'] == 'supervisor';
bool canManage(Map<String, dynamic> profile) => isAdmin(profile) || isSupervisor(profile);

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
}

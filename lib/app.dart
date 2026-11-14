import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'core/app_providers.dart';
import 'core/app_scroll_behavior.dart';
import 'core/app_theme.dart';
import 'data/easy_ncc_repository.dart';
import 'features/auth/auth_pages.dart';
import 'features/shell/main_shell.dart';

class EasyNccApp extends StatelessWidget {
  const EasyNccApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy NCC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const EasyNccScrollBehavior(),
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontFamilyFallback: ['Noto Sans Bengali', 'Nirmala UI', 'Vrinda']),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final repository = ref.watch(repositoryProvider);

    if (!AppConfig.isSupabaseReady || client == null) {
      return const SetupRequiredPage();
    }

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return LoginPage(client: client, repository: repository);

        return FutureBuilder<Map<String, dynamic>>(
          future: repository.getMyProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return ProfileLoadErrorPage(error: profileSnapshot.error.toString());
            }
            if (!profileSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return MainShell(
              repository: repository,
              profile: profileSnapshot.data!,
              demoMode: false,
            );
          },
        );
      },
    );
  }
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/branding/bncc_logo.png', width: 112, height: 112),
                  const SizedBox(height: 18),
                  Text('Easy NCC', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Supabase সংযোগ এখনো সেটআপ করা হয়নি।', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Live Login, Cloud Database ও User Roles চালু করতে Supabase Project URL এবং Publishable Key দিয়ে App Run করুন।',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MainShell(
                        repository: EasyNccRepository(),
                        profile: const {'id': 'demo-member', 'display_name': 'Demo Admin', 'role': 'admin', 'cadet_number': 'DEMO-001', 'unit_name': 'Demo Unit'},
                        demoMode: true,
                      ),
                    )),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Demo Preview দেখুন'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
                      title: const Text('Supabase Setup'),
                      content: const Text('১. lib/core/app_config.dart খুলে Supabase Project URL ও Publishable Key একবার বসান।\n\n২. supabase/schema.sql Supabase SQL Editor-এ Run করুন।\n\n৩. Terminal-এ flutter run -d chrome চালান।'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ঠিক আছে'))],
                    )),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Setup নির্দেশনা'),
                  ),
                  const SizedBox(height: 12),
                  Text('Demo Preview-এর তথ্য শুধু এই Session-এ থাকবে; এটি Supabase-এ Save হয় না।',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileLoadErrorPage extends StatelessWidget {
  const ProfileLoadErrorPage({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text('প্রোফাইল লোড করা যায়নি'),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Logout')),
        ]),
      )),
    );
  }
}

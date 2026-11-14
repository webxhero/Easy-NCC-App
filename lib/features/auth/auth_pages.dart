import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_widgets.dart';
import '../../data/easy_ncc_repository.dart';
import '../events/events_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.client, required this.repository});
  final SupabaseClient client;
  final EasyNccRepository repository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      showMessage(context, 'Email এবং Password লিখুন।', error: true); return;
    }
    setState(() => _busy = true);
    try {
      await widget.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Login করা যায়নি: $e', error: true);
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) { showMessage(context, 'আগে Email লিখুন।', error: true); return; }
    try {
      await widget.client.auth.resetPasswordForEmail(_email.text.trim());
      if (mounted) showMessage(context, 'Password reset link পাঠানো হয়েছে।');
    } catch (e) { if (mounted) showMessage(context, '$e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: AppLogo(size: 76)),
              const SizedBox(height: 24),
              Text('Welcome back', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.greenDark)),
              const SizedBox(height: 6),
              const Text('আপনার Easy NCC Account-এ Login করুন।', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 14),
              TextField(controller: _password, obscureText: _hidePassword,
                decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _resetPassword, child: const Text('Forgot password?'))),
              const SizedBox(height: 8),
              FilledButton(onPressed: _busy ? null : _login,
                child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => RegisterPage(client: widget.client))), child: const Text('Create new account')),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PublicEventsPage(repository: widget.repository))),
                icon: const Icon(Icons.public), label: const Text('সবার জন্য Central Activities দেখুন'),
              ),
            ]),
          )),
        ),
      )),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.client});
  final SupabaseClient client;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 8) {
      showMessage(context, 'নাম, সঠিক Email এবং কমপক্ষে ৮ অক্ষরের Password দিন।', error: true); return;
    }
    setState(() => _busy = true);
    try {
      await widget.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'display_name': _name.text.trim()},
      );
      if (mounted) {
        showMessage(context, 'Registration হয়েছে। Email Verification সম্পন্ন করে Login করুন।');
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) { if (mounted) showMessage(context, '$e', error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(22),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const AppLogo(size: 62), const SizedBox(height: 20),
              Text('নতুন Account তৈরি করুন', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Registration Open। নতুন Account-এর Default Role হবে Member।'),
              const SizedBox(height: 20),
              TextField(controller: _name, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: _hide,
                decoration: InputDecoration(labelText: 'Password (minimum 8 characters)', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _register,
                child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Account')),
            ],
          ))),
        ),
      )),
    );
  }
}

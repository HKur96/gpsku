import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Bootstrap Login Screen adhering strictly to user stack:
/// Provider/ChangeNotifier for global state, ValueNotifier for ephemeral UI state.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _totpController;

  // Local ephemeral state managed strictly via ValueNotifier (No setState / No BLoC)
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _rememberMe = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _emailController = TextEditingController(
      text: authProvider.savedEmail ?? '',
    );
    _passwordController = TextEditingController();
    _totpController = TextEditingController();
    _rememberMe.value = authProvider.isRememberMe;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _obscurePassword.dispose();
    _rememberMe.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final code = _totpController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    await auth.login(
      email: email,
      password: password,
      code: code.isNotEmpty ? code : null,
      rememberMe: _rememberMe.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.authenticating;
    final isTotp = auth.status == AuthStatus.totpRequired;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 64,
                    color: Color(0xFF1E88E5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GPSku Telematics',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fleet Tracking & Remote Telemetry Client',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error message banner
                  if (auth.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Input Field with Obscure Toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: _obscurePassword,
                    builder: (context, obscure, _) {
                      return TextField(
                        controller: _passwordController,
                        obscureText: obscure,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => _obscurePassword.value = !obscure,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2FA TOTP Input Field if challenged
                  if (isTotp) ...[
                    TextField(
                      controller: _totpController,
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Two-Factor Code (TOTP)',
                        prefixIcon: Icon(Icons.security),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Remember Me Checkbox
                  ValueListenableBuilder<bool>(
                    valueListenable: _rememberMe,
                    builder: (context, remember, _) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Remember Me',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: remember,
                        onChanged: isLoading
                            ? null
                            : (val) => _rememberMe.value = val ?? false,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isTotp ? 'Verify & Sign In' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

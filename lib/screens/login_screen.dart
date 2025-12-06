// lib/screens/login_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/app_user.dart';
import '../routes.dart';
import '../services/session_manager.dart';

/// LoginScreen
/// -----------
///
/// Entry point for **mobile users**.
///
/// Responsibilities:
/// - Collect username and password.
/// - Call `POST /api/user-login` on the Next.js backend.
/// - Parse the returned user payload into [AppUser].
/// - Persist the user using [SessionManager.saveUser] so that future launches
///   can skip the login step.
/// - Navigate to the **User Zone** screen on success.
///
/// UI / UX:
/// - Dark card centered on the screen (mirrors the admin dashboard feel).
/// - Password show/hide toggle.
/// - Clear error banner for failed login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Controllers for the username and password text fields.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Whether the login request is in progress.
  bool _loading = false;

  /// Controls whether the password is visible or obscured.
  bool _obscurePassword = true;

  /// Optional error message shown above the button when login fails.
  String? _error;

  /// Performs the login flow:
  ///
  /// 1. Sends `POST /api/user-login` with JSON body:
  ///    `{ "username": "...", "password": "..." }`.
  /// 2. If the response is successful and `success == true`:
  ///    - Builds an [AppUser] from `data["user"]`.
  ///    - Saves that user using [SessionManager.saveUser].
  ///    - Navigates to the **User Zone** screen, replacing the login screen.
  /// 3. On error:
  ///    - Sets an error message to be displayed in the UI.
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$kBaseUrl/api/user-login');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode != 200 || data['success'] != true) {
        setState(() {
          _error =
              (data['message'] as String?) ??
              'Login failed. Please check your credentials.';
        });
        return;
      }

      // Parse user payload returned from the backend.
      final userJson = data['user'] as Map<String, dynamic>;
      final user = AppUser.fromJson(userJson);

      // Persist session so next app launch can restore the user.
      await SessionManager.saveUser(user);

      if (!mounted) return;

      // Navigate to the user zone screen, replacing the login screen.
      Navigator.of(
        context,
      ).pushReplacementNamed(Routes.userZone, arguments: user);
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
      debugPrint('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // Matches the dark surfaces used in the dashboard.
                color: const Color(0xFF020617).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon / app identity
                  Icon(
                    Icons.location_on,
                    size: 48,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'User Zone Login',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your credentials to see your zone',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 24),

                  // Username field
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password field with show/hide toggle
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error banner (if any)
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Primary action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
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

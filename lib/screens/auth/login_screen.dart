import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_allergy_identifier/routes.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        developer.log(
          'Attempting to login with email: ${_emailController.text.trim()}',
        );
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        developer.log('Login successful');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.homeScreen,
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        developer.log(
          'FirebaseAuthException during login',
          error: e,
          stackTrace: e.stackTrace,
          name: 'LoginScreen',
        );
        developer.log('Error code: ${e.code}');
        developer.log('Error message: ${e.message}');
        setState(() {
          _errorMessage = _getMessageFromErrorCode(e.code);
        });
      } catch (e, stackTrace) {
        developer.log(
          'Unexpected error during login',
          error: e,
          stackTrace: stackTrace,
          name: 'LoginScreen',
        );
        setState(() {
          _errorMessage = 'An error occurred. Please try again later.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // Add back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.home,
              (route) => false,
            );
          },
        ),
        // Show debug indicator in debug mode
        actions: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DEBUG',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 450 : double.infinity,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo or icon for desktop
                  if (isDesktop) ...[
                    const Icon(
                      Icons.health_and_safety,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'LOGIN',
                                style: TextStyle(fontSize: 16),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () => Navigator.pushReplacementNamed(
                              context,
                              Routes.signup,
                            ),
                    child: const Text("Don't have an account? Sign Up"),
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

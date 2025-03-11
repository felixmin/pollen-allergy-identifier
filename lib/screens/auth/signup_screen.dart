import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_allergy_identifier/routes.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        developer.log(
          'Attempting to create account with email: ${_emailController.text.trim()}',
        );
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        developer.log('Account creation successful');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully!')),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.homeScreen,
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        developer.log(
          'FirebaseAuthException during signup',
          error: e,
          stackTrace: e.stackTrace,
          name: 'SignupScreen',
        );
        developer.log('Error code: ${e.code}');
        developer.log('Error message: ${e.message}');
        setState(() {
          _errorMessage = _getMessageFromErrorCode(e.code);
        });
      } catch (e, stackTrace) {
        developer.log(
          'Unexpected error during signup',
          error: e,
          stackTrace: stackTrace,
          name: 'SignupScreen',
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

  // Helper method to get user-friendly error messages
  String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email or try logging in.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
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
        title: const Text('Sign Up'),
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
                      'Create an Account',
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
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
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
                                'SIGN UP',
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
                              Routes.login,
                            ),
                    child: const Text('Already have an account? Log In'),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gnoo/auth/register_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../main/main_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showPasswordField = false;
  bool _isEmailValid = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static const animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUIOverlayStyle();
    });
  }

  void _setSystemUIOverlayStyle() {
    final colorScheme = Theme.of(context).colorScheme;
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: colorScheme.brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: colorScheme.brightness,
      systemNavigationBarColor: colorScheme.background,
      systemNavigationBarIconBrightness:
          colorScheme.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Reset email validation state to allow user to edit email again
  void _resetEmailState() {
    setState(() {
      _isEmailValid = false;
      _showPasswordField = false;
    });
  }

  Future<void> _checkEmail() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showErrorSnackBar('Masukkan email yang valid');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email exists in Firestore
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('koleksi_users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      setState(() {
        _showPasswordField = userQuery.docs.isNotEmpty;
        _isEmailValid = userQuery.docs.isNotEmpty;
      });

      if (!userQuery.docs.isNotEmpty) {
        _showErrorSnackBar('Email tidak terdaftar');
      }
    } catch (e) {
      print('Error checking email: $e');
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final UserCredential userCredential =
            await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        await _processUserLogin(userCredential.user!);
      } on FirebaseAuthException catch (e) {
        _handleAuthError(e);
      } catch (e) {
        _showErrorSnackBar('Kata sandi salah');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Pengguna membatalkan proses login
        print('Error: Google sign in aborted by user.');
        _showErrorSnackBar('Masuk dengan Google dibatalkan.');
        return; // Stop eksekusi lebih lanjut
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        print('Error: Google sign in did not return an access token.');
        _showErrorSnackBar(
            'Gagal masuk dengan Google: Access Token tidak didapatkan.');
        return; // Stop eksekusi lebih lanjut
      }

      if (googleAuth.idToken == null) {
        print('Error: Google sign in did not return an ID token.');
        _showErrorSnackBar(
            'Gagal masuk dengan Google: ID Token tidak didapatkan.');
        return; // Stop eksekusi lebih lanjut
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      await _processUserLogin(userCredential.user!, isGoogleSignIn: true);
    } catch (e) {
      // Handle specific Firebase Authentication errors
      if (e is FirebaseAuthException) {
        print('Firebase Authentication Error: ${e.code} - ${e.message}');

        switch (e.code) {
          case 'account-exists-with-different-credential':
            _showErrorSnackBar(
                'Akun dengan email yang sama sudah ada dengan metode login yang berbeda.');
            break;
          case 'invalid-credential':
            _showErrorSnackBar(
                'Gagal masuk dengan Google: Kredensial tidak valid. Coba lagi atau periksa konfigurasi OAuth.');
            break;
          case 'operation-not-allowed':
            _showErrorSnackBar(
                'Gagal masuk dengan Google: Metode login Google belum diaktifkan di Firebase.');
            break;
          case 'user-disabled':
            _showErrorSnackBar('Akun ini telah dinonaktifkan.');
            break;
          case 'user-not-found':
            _showErrorSnackBar('Akun tidak ditemukan.');
            break;
          case 'web-storage-unsupported':
            _showErrorSnackBar(
                'Browser Anda tidak mendukung cookies pihak ketiga atau local storage. Pastikan Anda mengaktifkannya.');
            break;
          default:
            _showErrorSnackBar('Gagal masuk dengan Google: ${e.message}');
        }
      } else {
        // Handle general errors
        print('General Error during Google Sign In: $e');
        _showErrorSnackBar('Gagal masuk dengan Google: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processUserLogin(User user,
      {bool isGoogleSignIn = false}) async {
    if (!user.emailVerified && !isGoogleSignIn) {
      _showErrorSnackBar('Email belum diverifikasi. Silakan cek email Anda.');
      return;
    }

    final DocumentSnapshot userData = await FirebaseFirestore.instance
        .collection('koleksi_users')
        .doc(user.uid)
        .get();

    if (!userData.exists) {
      // Create user document if it doesn't exist (for Google Sign-In)
      await FirebaseFirestore.instance
          .collection('koleksi_users')
          .doc(user.uid)
          .set({
        'username': user.displayName ?? '',
        'email': user.email,
        'nama_lengkap': user.displayName ?? '',
        'alamat': '',
        'created_at': FieldValue.serverTimestamp(),
        'is_email_verified': isGoogleSignIn ? true : user.emailVerified,
      });
    } else if (!isGoogleSignIn &&
        !(userData.data() as Map<String, dynamic>)['is_email_verified']) {
      _showErrorSnackBar('Email belum diverifikasi. Silakan cek email Anda.');
      return;
    }

    // Store UID in shared preferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', user.uid);

    // Navigate to MainPage
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageTransition(
          type: PageTransitionType.sharedAxisHorizontal,
          child: const MainPage(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Masukkan email Anda terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link reset password telah dikirim ke email Anda'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan. Silakan coba lagi.';

      if (e.code == 'user-not-found') {
        message = 'Email tidak terdaftar';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid';
      }

      _showErrorSnackBar(message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = 'Kata sandi salah';
    if (e.code == 'user-not-found') {
      errorMessage = 'Email tidak terdaftar';
    } else if (e.code == 'wrong-password') {
      errorMessage = 'Kata sandi salah';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'Email tidak valid';
    }
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hai,\nSelamat\nDatang',
                  style: textTheme.displaySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // Email Field with Undo button if email is validated
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isEmailValid,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                        labelText: 'Email',
                        hintText: 'Masukkan email Anda',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        // Add padding to prevent text from being covered by undo button
                        contentPadding: EdgeInsets.only(
                          left: 16,
                          top: 16,
                          bottom: 16,
                          right: _isEmailValid ? 48 : 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Masukkan email yang valid';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Animated Container for Continue Button and Password Field
                AnimatedContainer(
                  duration: animationDuration,
                  height: _showPasswordField
                      ? 200
                      : 56, // Adjust height based on content
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Continue Button (visible when password field is hidden)
                        AnimatedOpacity(
                          duration: animationDuration,
                          opacity: _showPasswordField ? 0 : 1,
                          child: AnimatedContainer(
                            duration: animationDuration,
                            height: _showPasswordField ? 0 : 56,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _checkEmail,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text('Lanjutkan'),
                            ),
                          ),
                        ),

                        // Password Field Section (animated)
                        AnimatedOpacity(
                          duration: animationDuration,
                          opacity: _showPasswordField ? 1 : 0,
                          child: AnimatedContainer(
                            duration: animationDuration,
                            height: _showPasswordField ? 200 : 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Change Email Button
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed:
                                        _isLoading ? null : _resetEmailState,
                                    icon: Icon(
                                      Icons.arrow_back,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                    label: Text(
                                      'Ganti Email',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: colorScheme.surfaceVariant
                                        .withOpacity(0.5),
                                    labelText: 'Kata Sandi',
                                    hintText: 'Masukkan kata sandi Anda',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Kata sandi tidak boleh kosong';
                                    }
                                    if (value.length < 6) {
                                      return 'Kata sandi minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handleForgotPassword(),
                                    child: Text(
                                      'Lupa Kata Sandi?',
                                      style:
                                          TextStyle(color: colorScheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: FilledButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text('Masuk'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Google Login Button
                AnimatedOpacity(
                  duration: animationDuration,
                  opacity: _showPasswordField ? 0 : 1,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      side: BorderSide(color: colorScheme.outline),
                    ),
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 24,
                      height: 24,
                    ),
                    label: Text(
                      'Masuk dengan Google',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Daftar',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../Screens/admin/admin_dashboard.dart'; // Adjust path as needed
import '../Screens/volunteer/volunteer_page.dart'; // Adjust path as needed
import '../Screens/store_owner/store_dashboard.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/NotificationService.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // --- FORMS AND CONTROLLERS ---
  final _form = GlobalKey<FormState>();
  final _joinForm = GlobalKey<FormState>(); // New form for the join code UI

  // Controllers for Login/Register UI
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _contactC = TextEditingController();

  // New controller for Join Code UI
  final _joinCodeC = TextEditingController();

  // --- STATE VARIABLES ---
  bool _isLogin = true;
  bool _loading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    // Dispose all controllers
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _contactC.dispose();
    _joinCodeC.dispose();
    super.dispose();
  }

  // =========================================================================
  // --- NEW: Logic to handle Store Owner "Join with Code" ---
  // =========================================================================
  Future<void> _submitJoinCode() async {
    if (!_joinForm.currentState!.validate()) return;
    setState(() => _loading = true);

    final joinCode = _joinCodeC.text.trim().toUpperCase();
    String? err;
    String? storeName; // To pass to the dashboard on success
    String? userEmailForDashboard; // The email we create for the user

    try {
      // 1. Find the store with the matching join code
      final storeQuery = await _firestore
          .collection('stores')
          .where('joinCode', isEqualTo: joinCode)
          .limit(1)
          .get();

      if (storeQuery.docs.isEmpty) {
        err = 'Invalid join code. Please check the code and try again.';
      } else {
        final storeDoc = storeQuery.docs.first;
        final storeData = storeDoc.data();
        storeName = storeData['name']; // Get store name for later use

        // 2. Check if the store has already been claimed

        // 3. Store is valid and unclaimed. Create a user record.
        // We'll create a unique email for the store owner.
        final userEmail = "store_${joinCode.toLowerCase()}@foodlink.app";
        userEmailForDashboard = userEmail;

        final newUserPayload = {
          'name': storeName, // Use the store's name as the user's name
          'email': userEmail,
          'role': 'StoreOwner',
          'storeName': storeName,
          'createdAt': Timestamp.now(),
        };

        final newUserRef = await _firestore
            .collection('users')
            .add(newUserPayload);

        // 4. Link the new user's ID back to the store document
        await storeDoc.reference.update({'ownerUserId': newUserRef.id});
        // Success!
      }
    } catch (e) {
      print('Join Code Error: $e');
      err = 'An unexpected error occurred. Please try again.';
    }

    setState(() => _loading = false);

    // --- Handle errors and navigation ---
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    // --- Success Case ---
    // --- Success Case ---
    // --- Success Case ---
    if (mounted && storeName != null) {
      // This check makes our use of '!' safe
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store successfully registered!'),
          backgroundColor: Colors.green,
        ),
      );
      _joinCodeC.clear();
      // Navigate to the store dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // --- FIX APPLIED HERE ---
          builder: (context) => StoreDashboard(
            storeName: storeName!,
          ), // Use '!' to assert it's not null
        ),
      );
    }
  }

  // =========================================================================
  // --- EXISTING: Logic for Admin and Volunteer Login/Registration ---
  // =========================================================================
  Future<void> _submit(String role) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    String? err;
    bool isRegistration =
        !_isLogin; // Flag to check if it was a registration action

    try {
      if (_isLogin) {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: _emailC.text.trim())
            .where(
              'password',
              isEqualTo: _passC.text.trim(),
            ) // WARNING: Insecure
            .where('role', isEqualTo: role)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          err = 'Invalid credentials or user role does not match.';
        }
      } else {
        // --- Registration Logic ---
        final existingUser = await _firestore
            .collection('users')
            .where('email', isEqualTo: _emailC.text.trim())
            .limit(1)
            .get();

        if (existingUser.docs.isNotEmpty) {
          err = 'An account with this email already exists.';
        } else {
          Map<String, dynamic> userData = {
            'name': _nameC.text.trim(),
            'email': _emailC.text.trim(),
            'password': _passC.text.trim(), // WARNING: Insecure
            'role': role,
            'contact': _contactC.text.trim(),
            'createdAt': Timestamp.now(),
          };

          await _firestore.collection('users').add(userData);
          // Registration successful
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: _emailC.text.trim())
              .where('password', isEqualTo: _passC.text.trim())
              .where('role', isEqualTo: role)
              .limit(1)
              .get();
          final userId = userQuery.docs.first.id;
          await saveFcmToken(userId);
        }
      }
    } catch (e) {
      // It's good practice to log the actual error for debugging
      print('Firestore Error: $e');
      err = 'An unexpected error occurred. Please try again.';
    }

    // Stop loading indicator regardless of outcome
    setState(() => _loading = false);

    // --- Handle errors and navigation ---

    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    // --- Success Case ---

    if (mounted) {
      // Check if the widget is still in the tree
      if (mounted) {
        if (isRegistration) {
          // AFTER SUCCESSFUL REGISTRATION:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please log in.'),
            ),
          );
          setState(() {
            _isLogin = true;
            _passC.clear();
          });
        } else {
          // AFTER SUCCESSFUL LOGIN:

          // The user's email is in the controller
          final userEmail = _emailC.text.trim();

          // Clear the input fields for good practice
          _emailC.clear();
          _passC.clear();

          // Redirect the user based on their role, passing the email as an argument
          if (role == 'Admin') {
            final notificationService = NotificationService();

            // 1. Initialize notifications
            await notificationService.initialize();

            // 3. Schedule the daily admin notification
            notificationService.scheduleDailyAdminCheck();

            // 4. Navigate to the dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboard(userEmail: userEmail),
              ),
            );
          } else if (role == 'Volunteer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VolunteerPage(userEmail: userEmail),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments ?? {})
            as Map<String, dynamic>;
    final role = args['role'] as String? ?? 'Volunteer';

    // =====================================================================
    // --- RENDER THE CORRECT UI BASED ON THE ROLE ---
    // =====================================================================
    return Scaffold(
      appBar: AppBar(
        title: Text(
          role == 'StoreOwner'
              ? 'Join Your Store'
              : '$role - ${_isLogin ? "Login" : "Register"}',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              // --- CONDITIONAL UI ---
              child: role == 'StoreOwner'
                  ? _buildJoinCodeForm() // Show simple "Join with Code" UI for Store Owners
                  : _buildLoginForm(
                      role,
                    ), // Show standard Login/Register UI for others
            ),
          ),
        ),
      ),
    );
  }

  Future<void> saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }
      print("FCM token saved: $token");
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }

  // --- WIDGET BUILDER FOR THE "JOIN WITH CODE" UI ---
  Widget _buildJoinCodeForm() {
    return Form(
      key: _joinForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Store Owner',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter the unique join code provided by the admin to register your store.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _joinCodeC,
            decoration: const InputDecoration(
              labelText: '6-Digit Join Code',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            // Automatically convert to uppercase for consistency
            inputFormatters: [UpperCaseTextFormatter()],
            validator: (v) => v == null || v.length != 6
                ? 'Enter a valid 6-digit code'
                : null,
          ),
          const SizedBox(height: 20),
          _loading
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Join'),
                  onPressed: _submitJoinCode,
                ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER FOR THE STANDARD LOGIN/REGISTER UI ---
  Widget _buildLoginForm(String role) {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!_isLogin)
            TextFormField(
              controller: _nameC,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => v!.isEmpty ? 'Enter name' : null,
            ),
          if (!_isLogin) const SizedBox(height: 8),
          if (!_isLogin)
            TextFormField(
              controller: _contactC,
              decoration: const InputDecoration(labelText: 'Contact number'),
              validator: (v) => v!.isEmpty ? 'Enter contact' : null,
            ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailC,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v!.contains('@') ? null : 'Enter valid email',
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passC,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) => v!.length < 6 ? 'At least 6 chars' : null,
          ),
          const SizedBox(height: 16),
          _loading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () => _submit(role),
                  child: Text(_isLogin ? 'Login' : 'Register'),
                ),

          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
              );
            },
            child: const Text("Forgot Password?"),
          ),

          TextButton(
            onPressed: () => setState(() => _isLogin = !_isLogin),
            child: Text(
              _isLogin
                  ? 'Don\'t have an account? Register'
                  : 'Have an account? Login',
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to automatically convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

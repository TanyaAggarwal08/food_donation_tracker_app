import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailC = TextEditingController();
  final _newPassC = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;

  Future<void> _resetPassword() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailC.text.trim())
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No user found with this email.")),
        );
      } else {
        final docId = q.docs.first.id;

        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'password': _newPassC.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password updated successfully!")),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _emailC,
                decoration: InputDecoration(labelText: "Email"),
                validator: (v) => v!.contains("@") ? null : "Enter valid email",
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _newPassC,
                obscureText: true,
                decoration: InputDecoration(labelText: "New Password"),
                validator: (v) =>
                    v!.length < 6 ? "At least 6 characters" : null,
              ),
              SizedBox(height: 20),
              _loading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _resetPassword,
                      child: Text("Reset Password"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

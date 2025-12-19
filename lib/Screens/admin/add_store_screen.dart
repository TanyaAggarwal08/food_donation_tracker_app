// lib/Screens/admin/add_store_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AddStoreScreen extends StatefulWidget {
  const AddStoreScreen({super.key});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    // 1. Generate a unique join code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    final rnd = Random();
    final joinCode = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

    try {
      // 2. Save store data to Firestore
      await FirebaseFirestore.instance.collection('stores').add({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'joinCode': joinCode,
        'createdAt': Timestamp.now(),
        'ownerUserId': null, // Can be filled later when the owner registers
      });

      // 3. Show success dialog with the code
      if (mounted) {
        _showSuccessDialog(joinCode);
        _nameController.clear();
        _addressController.clear();
        _phoneController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding store: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String joinCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Store Added Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this Join Code with the store owner:'),
            const SizedBox(height: 16),
            Center(
              child: SelectableText(
                joinCode,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a New Partner Store')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Store Name'),
                validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Store Address'),
                validator: (v) => v!.isEmpty ? 'Please enter an address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Store Contact Number'),
                validator: (v) => v!.isEmpty ? 'Please enter contact number' : null,
              ),
              const Spacer(),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save and Generate Code'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                onPressed: _addStore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
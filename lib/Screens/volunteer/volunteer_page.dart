import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'guide.dart';
import '../../Screens/volunteer/ContactStorePage.dart';

// Data classes remain at the top

class StoreInfo {
  final String id;
  final String name;
  final String address;
  final String? phone;

  StoreInfo({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
  });

  // Helper for simple display
  String get displayName => '$name ($address)';
}

class FoodItem {
  final String category;
  final int boxes;
  final double weight;
  final String useCase;

  FoodItem({
    required this.category,
    required this.boxes,
    required this.weight,
    required this.useCase,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'num_boxes': boxes,
      'weight_kg': weight,
      'use_case': useCase,
    };
  }
}

class PickupData {
  final String storeName;
  final List<FoodItem> foodItems;

  PickupData({required this.storeName, required this.foodItems});
}

class VolunteerPage extends StatefulWidget {
  final String userEmail;
  const VolunteerPage({super.key, required this.userEmail});

  @override
  State<VolunteerPage> createState() => _VolunteerPageState();
}

class _VolunteerPageState extends State<VolunteerPage> {
  // --- STATE VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _fs = FirestoreService();

  String? _volunteerName;
  String? _userId;
  bool _isSubmitting = false;
  bool _isLoadingInitialData = true;

  // --- Dynamic Data ---
  List<String> _foodCategories = [];

  // UPDATED: Use StoreInfo objects instead of strings/maps
  List<StoreInfo> _availableStores = [];
  StoreInfo? _selectedStore;

  final List<FoodItem> _currentFoodItems = [];

  // --- Overall Collected Data ---
  final List<PickupData> _pickups = [];
  final Set<String> _addedStoreNames = {};

  final TextEditingController _notesC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  // --- DATA & LOGIC METHODS ---

  Future<void> _loadInitialData() async {
    try {
      // 1. Fetch User
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        _volunteerName = userData['name'] ?? 'Volunteer';
        _userId = userQuery.docs.first.id;
      }

      // 2. Fetch Categories
      _foodCategories = await _fs.getFoodCategories();

      // 3. Fetch Stores (Name, Address, Phone)
      final storeSnapshot = await FirebaseFirestore.instance.collection('stores').get();

      final loadedStores = storeSnapshot.docs.map((doc) {
        final data = doc.data();
        return StoreInfo(
          id: doc.id,
          name: data['name'] ?? 'Unknown Store',
          address: data['address'] ?? 'No Address',
          phone: data['phone'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _availableStores = loadedStores;
        });
      }

    } catch (e) {
      _showErrorSnackBar('Could not fetch initial app data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    }
  }

  void _showAddCategoryDialog() {
    final categoryNameController = TextEditingController();
    final categoryFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: Form(
          key: categoryFormKey,
          child: TextFormField(
            controller: categoryNameController,
            decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g., Frozen'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category name.';
              }
              if (_foodCategories.any((cat) => cat.toLowerCase() == value.trim().toLowerCase())) {
                return 'This category already exists.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (categoryFormKey.currentState!.validate()) {
                final newCategoryRaw = categoryNameController.text.trim();
                final newCategory = newCategoryRaw.substring(0, 1).toUpperCase() + newCategoryRaw.substring(1).toLowerCase();
                try {
                  await _fs.addFoodCategory(newCategory);
                  setState(() {
                    _foodCategories.add(newCategory);
                  });
                  Navigator.of(ctx).pop();
                } catch (e) {
                  _showErrorSnackBar("Failed to save category: $e");
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFoodItemDialog(String category) {
    final boxesController = TextEditingController();
    final weightController = TextEditingController();
    String useCase = 'charity'; // Default use case

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $category Details'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: boxesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of Boxes'),
                ),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: useCase,
                  decoration: const InputDecoration(labelText: 'Use Case', border: OutlineInputBorder()),
                  items: ['charity', 'farm']
                      .map((uc) => DropdownMenuItem(value: uc, child: Text(uc)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => useCase = value);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final boxes = int.tryParse(boxesController.text) ?? 0;
              final weight = double.tryParse(weightController.text) ?? 0.0;
              if (boxes > 0 || weight > 0) {
                setState(() {
                  _currentFoodItems.add(FoodItem(
                    category: category,
                    boxes: boxes,
                    weight: weight,
                    useCase: useCase,
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addPickupToTable() {
    if (_formKey.currentState!.validate()) {
      if (_currentFoodItems.isEmpty) {
        _showErrorSnackBar('Please add at least one food item first.');
        return;
      }
      setState(() {
        // UPDATED: Extract .name from object
        _pickups.add(PickupData(
            storeName: _selectedStore!.name,
            foodItems: List.from(_currentFoodItems)
        ));
        _addedStoreNames.add(_selectedStore!.name);
        _resetFormFields();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pickup added to the summary table.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _resetFormFields() {
    _formKey.currentState?.reset();
    _currentFoodItems.clear();
    setState(() => _selectedStore = null);
  }

  void _editPickup(int index) {
    final pickupToEdit = _pickups[index];
    setState(() {
      // UPDATED: Find the object matching the name
      try {
        _selectedStore = _availableStores.firstWhere(
                (s) => s.name == pickupToEdit.storeName
        );
      } catch (e) {
        _selectedStore = null;
      }

      _currentFoodItems.clear();
      _currentFoodItems.addAll(pickupToEdit.foodItems);
      _pickups.removeAt(index);
      _addedStoreNames.remove(pickupToEdit.storeName);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Now editing pickup. Press "Add to Table" to re-save.'),
      backgroundColor: Colors.orange,
    ));
  }

  Future<void> _submitAllPickups() async {
    if (_pickups.isEmpty) {
      _showErrorSnackBar('The summary table is empty.');
      return;
    }
    setState(() => _isSubmitting = true);
    int successCount = 0;
    for (final pickup in _pickups) {
      final payload = {
        'user_id': _userId,
        'user_name': _volunteerName,
        'store_name': pickup.storeName,
        'datetime': Timestamp.now(),
        'food_data': pickup.foodItems.map((item) => item.toMap()).toList(),
        'verified_status': false,
        'notes': _notesC.text.trim(),
      };
      try {
        await _fs.addDelivery(payload);
        successCount++;
      } catch (e) {
        _showErrorSnackBar('Failed to submit for ${pickup.storeName}: $e');
      }
    }
    setState(() => _isSubmitting = false);
    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$successCount/${_pickups.length} pickups submitted!'),
          backgroundColor: Colors.green));
      setState(() {
        _pickups.clear();
        _addedStoreNames.clear();
        _notesC.clear();
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  // --- WIDGET BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_volunteerName != null ? 'Welcome, $_volunteerName!' : 'Volunteer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
              tooltip: 'How to Use This App',
              onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VolunteerGuidePage()),);
              }
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
          ),
        ],
      ),

      //New stuff added for sidebar
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _volunteerName ?? "Volunteer",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.userEmail,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text("Contact Stores"),
              onTap: () {
                //TODO: Navigate to ContactStores Page which is ConatctStorePage.dart
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactStorePage()),
                );
              },
            ),


          ],
        ),
      ),



      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDataEntryForm(),
            const SizedBox(height: 30),
            _buildSummaryTable(),
            const SizedBox(height: 30),
            _buildSubmissionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataEntryForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 1: Add Pickup Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- DROPDOWN ---
            DropdownButtonFormField<StoreInfo>(
              value: _selectedStore,
              hint: _availableStores.isEmpty
                  ? const Text('Loading stores...')
                  : const Text('Select a store'),
              isExpanded: true,
              isDense: false,
              itemHeight: null, // Allows items to expand vertically
              decoration: const InputDecoration(
                  labelText: 'Store',
                  border: OutlineInputBorder()
              ),
              items: _availableStores.map((store) {
                return DropdownMenuItem<StoreInfo>(
                  value: store,
                  enabled: !_addedStoreNames.contains(store.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            store.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _addedStoreNames.contains(store.name) ? Colors.grey : Colors.black87
                            )
                        ),
                        Text(
                          store.address,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedStore = value),
              validator: (value) => value == null ? 'Please select a store' : null,
            ),

            const SizedBox(height: 10),



            const SizedBox(height: 16),
            const Text('Add Items by Category:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._foodCategories.map((category) {
                  return ActionChip(
                    label: Text(category),
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () {
                      if (_selectedStore == null) {
                        _showErrorSnackBar('Please select a store first.');
                      } else {
                        _showFoodItemDialog(category);
                      }
                    },
                  );
                }),
                InkWell(
                  onTap: _showAddCategoryDialog,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.black54, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const Text('Items Added for this Store:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_currentFoodItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('No items added yet.')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _currentFoodItems.length,
                itemBuilder: (context, index) {
                  final item = _currentFoodItems[index];
                  return ListTile(
                    title: Text('${item.category} (${item.useCase})'),
                    subtitle: Text('Boxes: ${item.boxes}, Weight: ${item.weight}kg'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() => _currentFoodItems.removeAt(index)),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_to_photos_rounded),
                label: const Text('Add to Table'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _addPickupToTable,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTable() {
    // This now shows a summary of items per store.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 2: Review Pickups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_pickups.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No pickups added to the summary yet.')))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pickups.length,
            itemBuilder: (context, index) {
              final pickup = _pickups[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pickup.storeName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editPickup(index),
                                tooltip: 'Edit',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(() {
                                  _addedStoreNames.remove(_pickups[index].storeName);
                                  _pickups.removeAt(index);
                                }),
                                tooltip: 'Delete',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      ...pickup.foodItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.category} (${item.useCase})'),
                            Text('Boxes: ${item.boxes}, Weight: ${item.weight}kg'),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSubmissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 3: Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesC,
          decoration: const InputDecoration(
            labelText: 'Overall Notes (Optional)',
            hintText: 'e.g., Heavy traffic, special instructions...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Submit'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: _submitAllPickups,
          ),
        ),
      ],
    );
  }
}

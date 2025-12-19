// Future<void> _loadInitialData() async {
//   try {
//     // 1. Fetch volunteer data (Existing code)
//     final userQuery = await FirebaseFirestore.instance
//         .collection('users')
//         .where('email', isEqualTo: widget.userEmail)
//         .limit(1)
//         .get();
//
//     if (userQuery.docs.isNotEmpty) {
//       final userData = userQuery.docs.first.data();
//       _volunteerName = userData['name'] ?? 'Volunteer';
//       _userId = userQuery.docs.first.id;
//     }
//
//     // 2. Fetch categories (Existing code)
//     _foodCategories = await _fs.getFoodCategories();
//
//     // 3. NEW: Fetch Stores from Firestore
//     final storeQuery = await FirebaseFirestore.instance
//         .collection('stores')
//         .get();
//
//     final loadedStores = storeQuery.docs.map((doc) {
//       final data = doc.data();
//       return StoreInfo(
//         id: doc.id,
//         name: data['name'] ?? 'Unknown Store',
//         address: data['address'] ?? 'No Address',
//         phone: data['phone'], // Assumes field is named 'phone' or 'contactNumber'
//       );
//     }).toList();
//
//     // Update state
//     if (mounted) {
//       setState(() {
//         _availableStores = loadedStores;
//       });
//     }
//   } catch (e) {
//     _showErrorSnackBar('Could not fetch initial app data: $e');
//   } finally {
//     if (mounted) {
//       setState(() => _isLoadingInitialData = false);
//     }
//   }
// }

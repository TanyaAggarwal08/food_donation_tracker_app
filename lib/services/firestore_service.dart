import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  // --- Delivery Methods (Unchanged) ---

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllDeliveries() {
    return _fire.collection('deliveries').orderBy('datetime', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreDeliveries(String storeName) {
    return _fire.collection('deliveries')
        .where('store_name', isEqualTo: storeName)
        .orderBy('datetime', descending: true)
        .snapshots();
  }

  Future<void> addDelivery(Map<String, dynamic> data) async {
    await _fire.collection('deliveries').add(data);
  }

  Future<void> verifyDelivery(String docId, String adminUid) async {
    await _fire.collection('deliveries').doc(docId).update({
      'verified_status': true,
      'verified_by': adminUid,
      'verified_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDelivery(String docId) async {
    await _fire.collection('deliveries').doc(docId).delete();
  }

  Future<String?> getVolunteerFcmToken(String deliveryId) async {
    final doc = await FirebaseFirestore.instance
        .collection('deliveries')
        .doc(deliveryId)
        .get();

    if (!doc.exists){print("Delivery document not found."); return null;}

    final data = doc.data();
    final userName = data?['user_name'];

    print("Retrieved user name: $userName");


    if (userName == null) return null;

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isEqualTo: userName)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {print("User query not found."); return null;}

    return userQuery.docs[0].data()['fcmToken'];
  }


  // --- NEW, ROBUST METHODS FOR APP_DATA ---

  /// Fetches the dynamic list of food categories from Firestore.
  /// It reads from the 'food_categories' array in the 'app_data/lists' document.
  Future<List<String>> getFoodCategories() async {
    try {
      // Directly access the predictable document 'lists'.
      final doc = await _fire.collection('app_data').doc('lists').get();

      if (doc.exists && doc.data()!.containsKey('food_categories')) {
        final categoryData = doc.data()!['food_categories'] as List;
        return categoryData.map((category) => category.toString()).toList();
      }
      // Return a default list if the document or field doesn't exist.
      print("Warning: 'app_data/lists' document or 'food_categories' field not found. Using default list.");
      return ['Dairy', 'Produce', 'Bakery'];
    } catch (e) {
      print("Error fetching food categories: $e");
      // Fallback in case of network errors.
      return ['Dairy', 'Produce', 'Bakery'];
    }
  }

  /// Adds a new category to the 'food_categories' array in Firestore.
  /// This is now much safer and more efficient.
  Future<void> addFoodCategory(String newCategory) async {
    // Get a reference to the predictable document.
    final docRef = _fire.collection('app_data').doc('lists');

    // Use .set() with merge:true. This is the key change.
    // It will CREATE the document if it's missing, or safely
    // update it if it already exists, without overwriting other fields.
    // This permanently solves the '[cloud_firestore/not-found]' error.
    return docRef.set({
      'food_categories': FieldValue.arrayUnion([newCategory]),
    }, SetOptions(merge: true));
  }
}

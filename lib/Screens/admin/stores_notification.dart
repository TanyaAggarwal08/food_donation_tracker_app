import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StoresNoEntryPage extends StatefulWidget {
  final List<String> stores;

  const StoresNoEntryPage({super.key, required this.stores});

  @override
  State<StoresNoEntryPage> createState() => _StoresNoEntryPageState();
}

class _StoresNoEntryPageState extends State<StoresNoEntryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> notifyVolunteer({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    print(" notifyVolunteer called");
    print("Token = $fcmToken");
    print("Title = $title");
    print("Body  = $body");

    final url = Uri.parse("https://foodlinksoceity.onrender.com/notifyVolunteer");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": fcmToken,
          "title": title,
          "body": body,
        }),
      );

      print("API Status Code: ${response.statusCode}");
      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("Notification sent successfully");
      } else {
        debugPrint(" Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print(" Error sending notification: $e");
    }
  }

  ///  Notify all volunteers
  Future<void> _notifyAboutStore(String storeName) async {
    print("\n=========================================");
    print(" Starting volunteer notification for store: $storeName");
    print("=========================================");

    try {
      print("Fetching volunteers from Firestore...");
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Volunteer')
          .get();

      print('Total volunteers fetched: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print(doc.id);
        print(doc.data());
      }

      final validTokens = snapshot.docs
          .map((doc) {
        print("Checking volunteer doc: ${doc.id}");
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('fcmToken') && data['fcmToken'] != null && data['fcmToken'].toString().trim().isNotEmpty) {
          print("Volunteer token = ${data['fcmToken']}");
          return data['fcmToken'];
        } else {
          print(" No FCM token for volunteer: ${data['name']}");
          return null;
        }
      })
          .where((token) => token != null)
          .cast<String>()
          .toList();

      print("Valid tokens count: ${validTokens.length}");
      print("Valid tokens: $validTokens");

      if (validTokens.isEmpty) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No volunteers with valid FCM token found."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      for (var token in validTokens) {

        await notifyVolunteer(
          fcmToken: token,
          title: "Store Needs Pickup",
          body: "Please visit $storeName — no delivery entry recorded.",
        );
      }

      //print("✅ Notification process completed successfully.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Volunteers notified about: $storeName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      //print(" ERROR during volunteer notification: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error notifying volunteers: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(" Building StoresNoEntryPage");

    final filteredStores = widget.stores
        .where((s) => s.toLowerCase().contains(_searchQuery))
        .toList();

    print("Filtered stores count: ${filteredStores.length}");
    print("Search query: $_searchQuery");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stores Missing Entry", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search store name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    print(" Clearing search query");
                    setState(() {
                      _searchController.clear();
                      _searchQuery = "";
                    });
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                print("Search changed: $val");
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),

          Expanded(
            child: filteredStores.isEmpty
                ? const Center(child: Text("No stores found matching search."))
                : ListView.separated(
              itemCount: filteredStores.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final storeName = filteredStores[index];
                print("Rendering store tile: $storeName");

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('stores')
                      .where('name', isEqualTo: storeName)
                      .limit(1)
                      .get(),
                  builder: (context, snapshot) {
                    String address = "Loading address...";
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      address = snapshot.data!.docs.first['address'] ?? "Unknown Address";
                      print(" Address for $storeName = $address");
                    } else if (snapshot.connectionState == ConnectionState.done) {
                      address = "Address not found";
                      print(" Address not found for $storeName");
                    }

                    return ListTile(
                      title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(address),
                      trailing: IconButton(
                        icon: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
                        onPressed: () {
                          print(" Notify button pressed for $storeName");
                          _notifyAboutStore(storeName);
                        },
                        tooltip: "Notify Volunteers",
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

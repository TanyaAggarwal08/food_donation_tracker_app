import 'package:flutter/material.dart';

// This is the main widget for the guide page.
class VolunteerGuidePage extends StatelessWidget {
  const VolunteerGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The top bar of the page
      appBar: AppBar(
        title: const Text("How to Use This App"),
        // A subtle line under the app bar for a professional look
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      // The main content of the page, made scrollable with a ListView
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Step 1: Select a Store
          _buildStep(
            number: "1",
            title: "Select a Store",
            description:
            "Tap the box that says 'Select Store' to open a list. Choose the store where you are picking up food.",
            icon: Icons.store_mall_directory_outlined,
          ),
          // Step 2: Add Food Items
          _buildStep(
            number: "2",
            title: "Add Food Items",
            description:
            "Tap the buttons for food types (like 'Dairy', 'Produce'). Enter the number of boxes or the weight, then tap 'Add Item'.",
            icon: Icons.add_shopping_cart_rounded,
          ),
          // Step 3: Add to Summary Table
          _buildStep(
            number: "3",
            title: "Review Your Entry",
            description:
            "After adding items for one store, tap the blue 'Add to Summary Table' button. This saves your entry for that store and clears the form for the next one.",
            icon: Icons.playlist_add_check_rounded,
          ),
          // Step 4: Submit Your Report
          _buildStep(
            number: "4",
            title: "Submit All Pickups",
            description:
            "When you have finished adding entries for ALL the stores you visited, scroll to the bottom and tap the green 'Submit All Pickups' button. This sends all your saved entries to us.",
            icon: Icons.cloud_upload_rounded,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          // Help Section
          const Icon(
            Icons.support_agent_rounded,
            color: Colors.green,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            "Need Help?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "If you get stuck or make a mistake, don't worry! Please contact your admin or coordinator directly for help.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  // This is a helper widget to build each step consistently, so we don't repeat code.
  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The numbered circle on the left
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Text(
              number,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // The text content on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with an icon
                Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // The descriptive text
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4, // Increases spacing between lines for readability
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

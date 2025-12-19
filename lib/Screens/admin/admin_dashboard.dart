import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:test1/Screens/admin/Reports.dart';
import '../../services/firestore_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'add_store_screen.dart';
import 'store_data.dart';
import 'stores_notification.dart';

class AdminDashboard extends StatefulWidget {
  final String userEmail;
  const AdminDashboard({super.key, required this.userEmail});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirestoreService _fs = FirestoreService();
  List<String> _partnerStores = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchPartnerStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPartnerStores() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('stores').get();
      final storeNames = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['name'] ?? data['Name'] ?? '').toString();
      }).where((name) => name.trim().isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _partnerStores = storeNames;
        });
      }
    } catch (e) {
      debugPrint("Error fetching partner stores: $e");
    }
  }

  // --- FIXED POPUP DIALOG ---
  void _showDeliveryDetails(BuildContext context, Map<String, dynamic> data) {
    final foodData = data['food_data'];
    final List<dynamic> foodItems = foodData is List ? foodData : [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data['store_name'] ?? 'Delivery Details',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Using SizedBox with max height prevents full screen takeover but allows scrolling
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _detailRow(Icons.person, 'Volunteer:', data['user_name'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _detailRow(Icons.verified_user, 'Verified by:', data['verified_by'] ?? 'Pending'),
                    ],
                  ),
                ),

                // Notes Section
                if (data['notes'] != null && data['notes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      data['notes'],
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.brown[800], fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),

                // Food Items List
                Text("Food Items Collected", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const SizedBox(height: 12),

                if (foodItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No food items recorded.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...foodItems.map((item) {
                    final itemData = item is Map<String, dynamic> ? item : <String, dynamic>{};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemData['category'] ?? 'Unknown Category',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${itemData['num_boxes'] ?? 0} boxes • ${itemData['weight_kg'] ?? 0} kg',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              itemData['use_case'] ?? 'N/A',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // Helper for details row to prevent overflow
  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> notifyVolunteer({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    // ... (Keep existing implementation)
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
      if (response.statusCode == 200) {
        debugPrint("Notification sent successfully");
      } else {
        debugPrint("Failed to send notification: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey[200], height: 1.0),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_business_outlined, color: Colors.green[700]),
            tooltip: 'Add New Store',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStoreScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false),
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade800, Colors.green.shade600],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, size: 32, color: Colors.green.shade800),
              ),
              accountName: const Text("Admin Controls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(widget.userEmail, style: TextStyle(color: Colors.green.shade50)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports & Analytics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(userEmail: widget.userEmail)));
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.store_mall_directory_rounded,
                    title: 'Store Database',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreDataPage()));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Version 1.0.0", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fs.streamAllDeliveries(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final allDocs = snap.data!.docs;

                // --- Filtering Logic ---
                final docs = allDocs.where((doc) {
                  final data = doc.data();
                  final storeName = (data['store_name'] ?? '').toString().toLowerCase();
                  final userName = (data['user_name'] ?? '').toString().toLowerCase();

                  bool matchesSearch = _searchQuery.isEmpty ||
                      storeName.contains(_searchQuery) ||
                      userName.contains(_searchQuery);

                  bool matchesDate = true;
                  if (_selectedDate != null) {
                    if (data['datetime'] is Timestamp) {
                      final date = (data['datetime'] as Timestamp).toDate();
                      matchesDate = date.year == _selectedDate!.year &&
                          date.month == _selectedDate!.month &&
                          date.day == _selectedDate!.day;
                    } else {
                      matchesDate = false;
                    }
                  }
                  return matchesSearch && matchesDate;
                }).toList();

                // --- Logic for Stats ---
                final unverifiedCount = allDocs.where((doc) => doc.data()['verified_status'] != true).length;
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);

                final storesWithEntriesToday = allDocs
                    .where((doc) {
                  final docTimestamp = doc.data()['datetime'];
                  if (docTimestamp is! Timestamp) return false;
                  final docDate = docTimestamp.toDate();
                  return docDate.year == todayStart.year &&
                      docDate.month == todayStart.month &&
                      docDate.day == todayStart.day;
                })
                    .map((doc) => (doc.data()['store_name'] as String? ?? '').trim().toLowerCase())
                    .where((name) => name.isNotEmpty)
                    .toSet();

                final storesWithNoEntry = _partnerStores
                    .where((store) => !storesWithEntriesToday.contains(store.trim().toLowerCase()))
                    .toList();

                // --- Grouping ---
                Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupedDeliveries = {};
                for (var doc in docs) {
                  final data = doc.data();
                  if (data['datetime'] is Timestamp) {
                    final date = (data['datetime'] as Timestamp).toDate();
                    final dateKey = DateFormat('MMMM d, yyyy').format(date);
                    if (!groupedDeliveries.containsKey(dateKey)) {
                      groupedDeliveries[dateKey] = [];
                    }
                    groupedDeliveries[dateKey]!.add(doc);
                  }
                }

                final sortedDates = groupedDeliveries.keys.toList()
                  ..sort((a, b) {
                    final dateA = DateFormat('MMMM d, yyyy').parse(a);
                    final dateB = DateFormat('MMMM d, yyyy').parse(b);
                    return dateB.compareTo(dateA);
                  });

                // --- Main Content ---
                return ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    _buildStatsSection(unverifiedCount, storesWithNoEntry),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text('Deliveries Feed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                        ],
                      ),
                    ),

                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('No deliveries found', style: TextStyle(color: Colors.grey[500])),
                          ],
                        )),
                      )
                    else
                      ...sortedDates.map((dateKey) {
                        final deliveriesForDate = groupedDeliveries[dateKey]!;
                        final shouldExpand = _searchQuery.isNotEmpty || _selectedDate != null || sortedDates.indexOf(dateKey) == 0;

                        return DateGroupCard(
                          dateKey: dateKey,
                          deliveries: deliveriesForDate,
                          fs: _fs,
                          userEmail: widget.userEmail,
                          onShowDetails: _showDeliveryDetails,
                          onNotify: notifyVolunteer,
                          isInitiallyExpanded: shouldExpand,
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search store or volunteer...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = "";
                    });
                  },
                )
                    : null,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () async {
              if (_selectedDate != null) {
                setState(() => _selectedDate = null);
              } else {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: Colors.green),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _selectedDate != null ? Colors.green.shade50 : Colors.white,
                border: Border.all(color: _selectedDate != null ? Colors.green : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: _selectedDate != null ? Colors.green[700] : Colors.grey[500]),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d').format(_selectedDate!),
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 14, color: Colors.green.shade800)
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700], size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87)),
        trailing: Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatsSection(int unverifiedCount, List<String> storesWithNoEntry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              count: unverifiedCount,
              title: 'Pending\nVerification',
              icon: Icons.hourglass_top_rounded,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              count: storesWithNoEntry.length,
              title: 'Stores with\nNo Entry Today',
              icon: Icons.store_mall_directory_outlined,
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoresNoEntryPage(stores: storesWithNoEntry),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DateGroupCard extends StatefulWidget {
  final String dateKey;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> deliveries;
  final FirestoreService fs;
  final String userEmail;
  final Function(BuildContext, Map<String, dynamic>) onShowDetails;
  final Function({required String fcmToken, required String title, required String body}) onNotify;
  final bool isInitiallyExpanded;

  const DateGroupCard({
    super.key,
    required this.dateKey,
    required this.deliveries,
    required this.fs,
    required this.userEmail,
    required this.onShowDetails,
    required this.onNotify,
    this.isInitiallyExpanded = false,
  });

  @override
  State<DateGroupCard> createState() => _DateGroupCardState();
}

class _DateGroupCardState extends State<DateGroupCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant DateGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.isInitiallyExpanded != oldWidget.isInitiallyExpanded) {
      _isExpanded = widget.isInitiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            widget.dateKey,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          subtitle: Text(
            '${widget.deliveries.length} entries',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          children: widget.deliveries.map((deliveryDoc) {
            final data = deliveryDoc.data();
            final bool verified = data['verified_status'] == true;
            final String userName = data['user_name'] ?? 'N/A';
            final String storeName = data['store_name'] ?? 'Unknown Store';

            String formattedTime = '';
            if (data['datetime'] is Timestamp) {
              formattedTime = DateFormat('hh:mm a').format((data['datetime'] as Timestamp).toDate());
            }

            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: verified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    verified ? Icons.check : Icons.access_time_filled,
                    color: verified ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                ),
                title: Text(storeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Row(
                  children: [
                    Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 4),
                    const Text("•", style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(userName, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!verified) ...[
                      _ActionButton(
                        icon: Icons.check,
                        color: Colors.green,
                        onTap: () async {
                          await widget.fs.verifyDelivery(deliveryDoc.id, widget.userEmail);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ActionButton(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Entry?"),
                              content: Text("Are you sure you want to remove the entry for $storeName?"),
                              actions: [
                                TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancel")),
                                TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                              ],
                            )
                        );
                        if(confirm == true) await widget.fs.deleteDelivery(deliveryDoc.id);
                      },
                    ),
                  ],
                ),
                onTap: () => widget.onShowDetails(context, data),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final int count;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.count,
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

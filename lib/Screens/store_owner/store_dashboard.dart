import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// A simple data class to hold our calculated totals
class StoreStats {
  final double totalWeight;
  final int totalBoxes;
  final Map<String, double> weightByCategory;
  final Map<String, double> monthlyTotals;
  final List<Map<String, dynamic>> history;

  StoreStats({
    this.totalWeight = 0.0,
    this.totalBoxes = 0,
    required this.weightByCategory,
    required this.monthlyTotals,
    required this.history,
  });
}

class StoreDashboard extends StatefulWidget {
  final String storeName; // Passed from AuthScreen

  const StoreDashboard({super.key, required this.storeName});

  @override
  State<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends State<StoreDashboard> {
  Future<StoreStats>? _storeStatsFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      _storeStatsFuture = _fetchStoreDataAndStats();
    });
  }

  // -----------------------------------------------------------
  //              UPDATED QUERY (OPTION 2 APPLIED)
  // -----------------------------------------------------------
  Future<StoreStats> _fetchStoreDataAndStats() async {
    print("Fetching data for Store Name (Login): '${widget.storeName}'");

    // STEP 1: Query only by store name + ordered by datetime
    QuerySnapshot deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('store_name', isEqualTo: widget.storeName)
        .orderBy('datetime', descending: true)
        .get();

    // Filter verified entries manually
    List<DocumentSnapshot> verifiedDocs = deliveriesSnapshot.docs
        .where((d) => d['verified_status'] == true)
        .toList();

    // Sort manually (descending)
    verifiedDocs.sort((a, b) {
      final dtA = (a['datetime'] as Timestamp).toDate();
      final dtB = (b['datetime'] as Timestamp).toDate();
      return dtB.compareTo(dtA);
    });

    // STEP 2: If no verified docs found, try fuzzy match
    if (verifiedDocs.isEmpty) {
      print("Exact match not found. Trying fuzzy search...");

      final allDeliveries = await FirebaseFirestore.instance
          .collection('deliveries')
          .orderBy('datetime', descending: true)
          .limit(100)
          .get();

      final matchingDocs = allDeliveries.docs.where((doc) {
        final dataName = (doc['store_name'] ?? '').toString().toLowerCase();
        final loginName = widget.storeName.toLowerCase();
        return dataName.contains(loginName) || loginName.contains(dataName);
      })
      // Filter verified in fuzzy search also
          .where((doc) => doc['verified_status'] == true)
          .toList();

      print("Found ${matchingDocs.length} verified fuzzy matches.");

      // Sort fuzzy results
      matchingDocs.sort((a, b) {
        final dtA = (a['datetime'] as Timestamp).toDate();
        final dtB = (b['datetime'] as Timestamp).toDate();
        return dtB.compareTo(dtA);
      });

      return _processDocs(matchingDocs);
    }

    return _processDocs(verifiedDocs);
  }

  // Helper method to process the documents
  StoreStats _processDocs(List<DocumentSnapshot> docs) {
    double totalWeight = 0;
    int totalBoxes = 0;
    Map<String, double> weightByCategory = {};
    Map<String, double> monthlyTotals = {};
    List<Map<String, dynamic>> history = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      history.add({...data, 'docId': doc.id});

      final dt = (data['datetime'] as Timestamp).toDate();
      final monthKey = DateFormat('MMM yyyy').format(dt);

      final rawItems = data['food_items'] ?? data['food_data'] ?? [];
      double donationWeight = 0;

      if (rawItems is List) {
        for (var rawItem in rawItems) {
          if (rawItem is Map) {
            final item = Map<String, dynamic>.from(rawItem);

            double w = double.tryParse(item['weight_kg']?.toString() ?? '0') ?? 0.0;
            int b = int.tryParse(item['num_boxes']?.toString() ?? '0') ?? 0;

            donationWeight += w;
            totalWeight += w;
            totalBoxes += b;

            final category = item['category']?.toString() ?? 'Unknown';

            weightByCategory[category] = (weightByCategory[category] ?? 0) + w;
          }
        }
      }
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + donationWeight;
    }

    return StoreStats(
      totalWeight: totalWeight,
      totalBoxes: totalBoxes,
      weightByCategory: weightByCategory,
      monthlyTotals: monthlyTotals,
      history: history,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.storeName} - Dashboard'),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<StoreStats>(
        future: _storeStatsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error: ${snap.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ));
          }
          if (!snap.hasData) {
            return const Center(child: Text("No data available."));
          }

          final stats = snap.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummary(stats),
                const SizedBox(height: 20),

                _buildLatestPickup(stats.history),
                const SizedBox(height: 30),

                Text("Category Breakdown",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildCategoryChart(stats.weightByCategory),

                const SizedBox(height: 30),
                Text("Monthly Donations",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildMonthlyChart(stats.monthlyTotals),

                const SizedBox(height: 30),
                Text("Donation History",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _buildHistoryList(stats.history),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(StoreStats stats) {
    return Row(
      children: [
        Expanded(
          child: _stat("Total Weight",
              "${stats.totalWeight.toStringAsFixed(1)} kg", Icons.scale, Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _stat("Total Boxes",
              stats.totalBoxes.toString(), Icons.inventory_2, Colors.orange),
        )
      ],
    );
  }

  Widget _stat(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // LATEST PICKUP
  Widget _buildLatestPickup(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    final latest = history.first;
    final vol = latest['user_name'] ?? "Unknown";
    final dt = (latest['datetime'] as Timestamp).toDate();
    final formatted = DateFormat('MMM d, yyyy • h:mm a').format(dt);

    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.shade100)
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.access_time, color: Colors.white),
        ),
        title: const Text("Most Recent Pickup", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Volunteer: $vol\nAt: $formatted"),
      ),
    );
  }

  // --- DYNAMIC CATEGORY CHART (GRID STYLE) ---
  Widget _buildCategoryChart(Map<String, double> data) {
    if (data.isEmpty || data.values.every((v) => v == 0)) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No category data available.", style: TextStyle(color: Colors.grey))),
      );
    }

    final validData = Map<String, double>.from(data)..removeWhere((k, v) => v <= 0);
    final keys = validData.keys.toList();
    final values = validData.values.toList();

    double maxY = (values.reduce((a, b) => a > b ? a : b)) * 1.2;
    if (maxY == 0) maxY = 10;
    maxY = (maxY / 10).ceil() * 10.0;

    return Container(
      height: 260,
      padding: const EdgeInsets.only(right: 16, left: 0, top: 10),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade400, strokeWidth: 1, dashArray: [5, 5]),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade400, strokeWidth: 1, dashArray: [5, 5]),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black54, width: 1),
          ),
          barGroups: List.generate(keys.length, (i) {
            Color barColor = Colors.blue;
            if (i == 1) barColor = Colors.green;
            if (i == 2) barColor = Colors.orange;

            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                color: barColor,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )
            ]);
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= keys.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      keys[value.toInt()],
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- SORTED MONTHLY CHART ---
  Widget _buildMonthlyChart(Map<String, double> monthly) {
    if (monthly.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: Text("No monthly data available.", style: TextStyle(color: Colors.grey))));
    }

    final sortedKeys = monthly.keys.toList()
      ..sort((a, b) {
        try {
          return DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b));
        } catch(e) { return 0; }
      });

    final values = sortedKeys.map((k) => monthly[k]!).toList();

    double maxY = 0;
    if (values.isNotEmpty) {
      maxY = (values.reduce((a, b) => a > b ? a : b)) * 1.2;
    }
    if (maxY == 0) maxY = 10;
    maxY = (maxY / 10).ceil() * 10.0;

    return Container(
      height: 260,
      padding: const EdgeInsets.only(right: 16, left: 0, top: 10),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade400, strokeWidth: 1, dashArray: [5, 5]),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade400, strokeWidth: 1, dashArray: [5, 5]),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black54, width: 1),
          ),
          barGroups: List.generate(sortedKeys.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                color: Colors.purple,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )
            ]);
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 11));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedKeys.length) return const SizedBox.shrink();
                  final fullDate = sortedKeys[value.toInt()];
                  final parts = fullDate.split(' ');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(parts[0], style: const TextStyle(fontSize: 10, color: Colors.black87)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- DONATION HISTORY ---
  Widget _buildHistoryList(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("No history available.", style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: history.map((entry) {
        final dt = (entry['datetime'] as Timestamp).toDate();
        final formattedDate = DateFormat('MMM d, yyyy').format(dt);
        final formattedTime = DateFormat('h:mm a').format(dt);
        final isVerified = entry['verified_status'] == true;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: ExpansionTile(
            shape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVerified ? Icons.check_circle_outline : Icons.hourglass_top,
                color: isVerified ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              formattedDate,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Row(
              children: [
                Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry['user_name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
            children: [
              const Divider(height: 1, indent: 16, endIndent: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Items Collected:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ..._buildFoodItems(entry['food_items'] ?? entry['food_data']),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildFoodItems(dynamic items) {
    if (items == null || items is! List) {
      return [const Text("No items recorded.", style: TextStyle(fontStyle: FontStyle.italic))];
    }

    return items.map<Widget>((item) {
      if (item is Map) {
        final category = item['category'] ?? 'Unknown';
        final boxes = item['num_boxes'] ?? 0;
        final weight = item['weight_kg'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 6, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text("$category: ", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("$boxes boxes, $weight kg", style: TextStyle(color: Colors.grey.shade800)),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }).toList();
  }
}

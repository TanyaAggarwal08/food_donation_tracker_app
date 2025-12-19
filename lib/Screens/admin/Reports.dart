import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


// --- DATA MODELS FOR CHARTING ---
// Model for store-wise data (currently unused in the provided code logic)
class StoreData {
  final String storeName;
  final int totalBoxes;
  StoreData(this.storeName, this.totalBoxes);
}

// Model for category-wise data (currently unused, color is calculated separately)
class CategoryData {
  final String category;
  final double totalWeight;
  final Color color;
  CategoryData(this.category, this.totalWeight, this.color);
}

// Main stateful widget for the Reports Dashboard
class ReportsPage extends StatefulWidget {
  final String userEmail;
  const ReportsPage({super.key, required this.userEmail});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {

  // SendGrid Configuration
  static const String _sendGridApiKey = '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'; // API Key for authentication
  static const String _fromEmail = 'societyfoodlink@gmail.com'; // Sender email (must be verified in SendGrid)
  static const String _fromName = 'FoodLink System'; // Sender name

  // List of recipients for the email report
  static const List<Map<String, String>> _recipients = [
    {'email': 'shubham.verma@mytwu.ca', 'name': 'Admin'},
    // Add more recipients here
  ];

  /// Downloads the comprehensive delivery data as a CSV file to the device.
  Future<void> _downloadCSVReport(BuildContext context) async {
    print('DOWNLOAD CSV BUTTON CLICKED!');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating CSV file...')),
    );

    try {
      // 1. Fetch all documents from the 'deliveries' Firestore collection
      print('Fetching delivery data...');
      final querySnapshot = await FirebaseFirestore.instance.collection(
          'deliveries').get();
      final docs = querySnapshot.docs;

      if (docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No delivery data available to download.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. Generate CSV content string
      print('Generating CSV...');
      final csvContent = _generateCSVReport(docs);

      // 3. Determine file name and path
      final fileName = 'FoodLink_Report_${DateFormat('yyyy-MM-dd_HHmm').format(
          DateTime.now())}.csv';
      String filePath;

      // Logic to save file, prioritizing Downloads (Android) or Documents (iOS fallback)
      if (Platform.isAndroid) {
        // Attempt to use Android's standard Downloads folder
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          filePath = '${directory.path}/$fileName';
        } else {
          // Fallback to app documents directory if Downloads folder is inaccessible
          final appDir = await getApplicationDocumentsDirectory();
          filePath = '${appDir.path}/$fileName';
        }
      } else {
        // For iOS/other platforms, use the standard application documents directory
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/$fileName';
      }

      // 4. Write CSV content to the file
      final file = File(filePath);
      await file.writeAsString(csvContent);

      print('File saved to: $filePath');

      // 5. Show success message with a Share action
      if (context.mounted) {
        final locationMsg = Platform.isAndroid
            ? 'CSV saved to Downloads folder!\n$fileName'
            : 'CSV saved: $fileName';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                // Use share_plus package to share the saved file
                await Share.shareXFiles(
                  [XFile(filePath)],
                  subject: 'FoodLink Delivery Report - ${DateFormat(
                      'yyyy-MM-dd').format(DateTime.now())}',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Handle any errors during fetching, file writing, or sharing
      print('ERROR: ${e.toString()}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }
  /// Generates the CSV content string from a list of Firestore delivery documents.
  String _generateCSVReport(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final buffer = StringBuffer();

    // CSV Headers
    buffer.writeln(
        'Store Name,Date/Time,Volunteer,Status,Verified At,Total Boxes,Total Weight (kg),Categories,Use Cases,Notes');

    // Iterate through each delivery document
    for (var doc in docs) {
      final data = doc.data();
      final foodList = data['food_data'] as List<dynamic>? ?? [];

      String cats = ''; // aggregated categories
      String uses = ''; // aggregated use cases
      int totalBoxes = 0;
      double totalWeight = 0;

      // Process food_data list
      for (var f in foodList) {
        if (f is Map<String, dynamic>) {
          String category = (f['category'] ?? '').toString();
          String useCase = (f['use_case'] ?? '').toString();

          if (category.isNotEmpty) {
            cats += category.replaceAll(',', ';') + ' | ';
          }
          if (useCase.isNotEmpty) {
            uses += useCase.replaceAll(',', ';') + ' | ';
          }

          totalBoxes += (f['num_boxes'] as num?)?.toInt() ?? 0;
          totalWeight += (f['weight_kg'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Clean trailing pipes
      cats = cats.isEmpty ? 'N/A' : cats.substring(0, cats.length - 3);
      uses = uses.isEmpty ? 'N/A' : uses.substring(0, uses.length - 3);

      // Format datetime (ALWAYS exists in your schema)
      final timestamp = data['datetime'] is Timestamp
          ? (data['datetime'] as Timestamp).toDate()
          : DateTime.now();

      // Format verification time
      final verifiedAt = data['verified_at'] is Timestamp
          ? DateFormat('yyyy-MM-dd HH:mm')
          .format((data['verified_at'] as Timestamp).toDate())
          : '';

      final verified = data['verified_status'] == true;

      // Clean fields for CSV
      String storeName =
      (data['store_name'] ?? 'Unknown Store').toString().replaceAll(',', ';');

      String volunteer =
      (data['user_name'] ?? 'N/A').toString().replaceAll(',', ';');

      String notes = (data['notes'] ?? '')
          .toString()
          .replaceAll(',', ';')
          .replaceAll('\n', ' ');

      // Write CSV row
      buffer.writeln(
          '"$storeName",'
              '"${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}",'
              '"$volunteer",'
              '${verified ? "VERIFIED" : "PENDING"},'
              '"$verifiedAt",'
              '$totalBoxes,'
              '${totalWeight.toStringAsFixed(2)},'
              '"$cats",'
              '"$uses",'
              '"$notes"');
    }

    return buffer.toString();
  }
  /// Sends the delivery data as a CSV attachment via email using the SendGrid API.
  Future<void> _sendEmailReport(BuildContext context) async {
    print('SEND EMAIL WITH ATTACHMENT BUTTON CLICKED!');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Preparing CSV report and sending email...')),
    );

    try {
      // 1. Fetch delivery data
      print('Fetching delivery data...');
      final querySnapshot = await FirebaseFirestore.instance.collection(
          'deliveries').get();
      final docs = querySnapshot.docs;

      if (docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No delivery data available to send.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. Generate CSV content
      print('Generating CSV...');
      final csvContent = _generateCSVReport(docs);

      // 3. Convert CSV to base64 for email attachment
      final csvBytes = utf8.encode(csvContent);
      final base64Csv = base64Encode(csvBytes);

      final fileName = 'FoodLink_Report_${DateFormat('yyyy-MM-dd_HHmm').format(
          DateTime.now())}.csv';

      // 4. Generate summary statistics for the email body
      final summary = _generateSummaryText(docs);

      // 5. Prepare SendGrid request payload
      final emailData = {
        'personalizations': [
          {
            'to': _recipients, // Target recipients list
            'subject': 'FoodLink Delivery Report - ${DateFormat('yyyy-MM-dd')
                .format(DateTime.now())}'
          }
        ],
        'from': {
          'email': _fromEmail,
          'name': _fromName
        },
        'content': [
          {
            'type': 'text/html', // Use HTML for a formatted email body
            'value': '''
              <html>
              <body style="font-family: Arial, sans-serif;">
                <div style="background-color: #4CAF50; color: white; padding: 20px; text-align: center;">
                  <h1> FoodLink Delivery Report</h1>
                  <p>${DateFormat('MMMM d, yyyy - HH:mm').format(
                DateTime.now())}</p>
                </div>
                
                <div style="padding: 20px;">
                  <p>Hello Admin,</p>
                  
                  <p>Please find attached the FoodLink delivery report in CSV format.</p>
                  
                  <div style="background-color: #f5f5f5; padding: 15px; border-left: 4px solid #4CAF50; margin: 20px 0;">
                    <h3> Quick Summary</h3>
                    <pre style="font-family: monospace;">$summary</pre>
                  </div>
                  
                  <p><strong>Attachment:</strong> $fileName</p>
                  
                  <p>You can open this file directly in Excel, Google Sheets, or any spreadsheet application.</p>
                </div>
                
                <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 12px; color: #666;">
                  <p>This is an automated report from FoodLink System</p>
                  <p>2025 FoodLink. All rights reserved.</p>
                </div>
              </body>
              </html>
            '''
          }
        ],
        'attachments': [
          {
            'content': base64Csv,
            'type': 'text/csv',
            'filename': fileName,
            'disposition': 'attachment' // Specifies it's an attachment
          }
        ]
      };

      print('Sending via SendGrid...');

      // 6. Send the request to the SendGrid API endpoint
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sendGridApiKey', // API key for authorization
        },
        body: jsonEncode(emailData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // 7. Check response status (202 Accepted means successful queuing)
      if (response.statusCode == 202) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV report sent successfully with attachment!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Log and throw error for non-202 status codes
        throw Exception(
            'SendGrid returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Handle errors during the email sending process
      print('ERROR: ${e.toString()}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  /// Generates a simple text summary of key delivery statistics.
  String _generateSummaryText(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int totalDeliveries = docs.length;
    // Count verified and pending deliveries
    int verifiedCount = docs
        .where((doc) => doc.data()['verified_status'] == true)
        .length;
    int pendingCount = totalDeliveries - verifiedCount;

    int totalBoxes = 0;
    double totalWeight = 0;

    // Calculate total boxes and weight across all deliveries
    for (var doc in docs) {
      final data = doc.data();
      final foodList = data['food_data'] as List<dynamic>? ?? [];

      for (var f in foodList) {
        if (f is Map<String, dynamic>) {
          totalBoxes += (f['num_boxes'] as num?)?.toInt() ?? 0;
          totalWeight += (f['weight_kg'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // Return the formatted summary string
    return '''Total Deliveries: $totalDeliveries
Verified: $verifiedCount
Pending: $pendingCount
Total Boxes: $totalBoxes
Total Weight: ${totalWeight.toStringAsFixed(2)} kg''';
  }

  /// Normalizes any category string to one of the 5 valid schema categories.
  /// Returns null if the category doesn't match any valid category.
  String? _normalizeCategory(String cat) {
    if (cat.isEmpty) return null;

    final lower = cat.trim().toLowerCase();

    // Exact matching based on schema categories
    if (lower == 'produce') {
      return 'Produce';
    } else if (lower == 'bakery') {
      return 'Bakery';
    } else if (lower == 'meat') {
      return 'Meat';
    } else if (lower == 'dairy') {
      return 'Dairy';
    } else if (lower == 'frozen food' || lower == 'frozen') {
      return 'Frozen Food';
    }

    // If it doesn't match any valid category, return null to skip it
    return null;
  }

  /// Maps a food category string to a specific Color for charting.
  Color _categoryColor(String c) {
    final normalized = c.toLowerCase();
    if (normalized.contains('dairy')) {
      return Colors.blueAccent;
    } else if (normalized.contains('produce')) {
      return Colors.green;
    } else if (normalized.contains('bakery') || normalized.contains('bread')) {
      return Colors.orange;
    } else if (normalized.contains('meat')) {
      return Colors.red;
    } else if (normalized.contains('frozen')) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }
  /// Creates a visual badge (Verified/Pending) for the delivery status.
  Widget _verificationBadge(bool status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status ? Colors.green.shade600 : Colors.red.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status ? "Verified" : "Pending",
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  /// Shortens long category labels for better display on charts.
  String _getShortenedLabel(String label) {
    // Standardize 'Fresh Produce' to 'Produce'
    if (label.toLowerCase().contains('fresh')) {
      return label.replaceFirst('Fresh ', '');
    }

    // Truncate overly long labels
    if (label.length > 10) {
      return '${label.substring(0, 7)}...';
    }

    return label;
  }

// ---------------------- BAR CHART ----------------------

  /// Builds a BarChart visualizing total weight per food category.
  Widget _buildBarChart(Map<String, double> totals) {
    if (totals.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No data available")),
      );
    }

    final keys = totals.keys.toList();
    final values = totals.values.toList();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          // Set max Y value slightly higher than the max data value
          maxY: (values.reduce((a, b) => a > b ? a : b)) + 20,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),

          // Horizontal grid lines only
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
          ),

          // ===== BAR GROUPS: Create a bar for each category =====
          barGroups: List.generate(keys.length, (i) {
            return BarChartGroupData(
              x: i, // X index for positioning
              barRods: [
                BarChartRodData(
                  toY: values[i], // Y value is the total weight
                  width: 22,
                  color: _categoryColor(keys[i]), // Color based on category
                  borderRadius: BorderRadius.circular(4),
                )
              ],
            );
          }),

          // ===== TITLES (AXES) =====
          titlesData: FlTitlesData(
            // ===== LEFT Y-AXIS (Weight) =====
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 40, // Interval for Y-axis labels
                getTitlesWidget: (value, meta) {
                  final display = value.toStringAsFixed(
                      value == value.truncateToDouble() ? 0 : 1);

                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      display,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Hide top & right axes
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),

            // ===== BOTTOM LABELS (Categories) =====
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70, // Reserve height for rotated labels
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= keys.length) {
                    return const SizedBox();
                  }

                  final label = _getShortenedLabel(keys[index]); // Get shortened name

                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: RotatedBox( // Rotate text 90 degrees for space-saving
                      quarterTurns: -1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 10),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),


          // ===== TOOLTIP (on bar touch) =====
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${rod.toY.toStringAsFixed(1)}", // Show weight with one decimal
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a PieChart visualizing the proportional weight distribution per food category.
  Widget _buildPieChart(Map<String, double> totals) {
    // Filter out categories with 0 weight
    final validTotals = Map.fromEntries(
        totals.entries.where((e) => e.value > 0));

    // Map valid totals to PieChartSectionData
    final sections = validTotals.entries.map((entry) {
      // Calculate total weight for percentage check
      final totalWeightSum = validTotals.values.reduce((a, b) => a + b);

      return PieChartSectionData(
        value: entry.value,
        color: _categoryColor(entry.key),
        // Only show label inside the slice if it's large enough (e.g., > 5% of total)
        title: entry.value < (totalWeightSum * 0.05)
            ? ''
            : '${entry.value.toStringAsFixed(1)} kg',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Column( // Structure for chart and legend
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // Center the PieChart itself
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 30, // Doughnut hole size
                sectionsSpace: 2, // Space between slices
              )),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Legend below the chart
        _buildLegend(validTotals),
      ],
    );
  }

  /// Helper function to build the legend using a Wrap layout.
  Widget _buildLegend(Map<String, double> totals) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 8.0),
      child: Wrap( // Allows items to flow onto new lines
        spacing: 16.0,
        runSpacing: 8.0,
        children: totals.entries.map((entry) {
          return _buildLegendItem(
            color: _categoryColor(entry.key),
            label: _getShortenedLabel(entry.key),
            value: entry.value,
          );
        }).toList(),
      ),
    );
  }

  /// Helper for a single legend item (color dot, label, and weight).
  Widget _buildLegendItem(
      {required Color color, required String label, required double value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.grey.shade300)
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label (${value.toStringAsFixed(1)} kg)',
          style: TextStyle(fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Builds a list view of individual delivery records.
  Widget _buildDeliveryList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(), // Prevent inner scrolling
      shrinkWrap: true,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final foodList = data['food_data'] as List<dynamic>? ?? [];

        // Aggregate food data for display
        String cats = '';
        String uses = '';
        int totalBoxes = 0;
        double totalWeight = 0;

        for (var f in foodList) {
          if (f is Map<String, dynamic>) {
            cats += "${(f['category'] ?? f['Category'] ?? '')} | ";
            uses += "${f['use_case'] ?? ''} | ";
            totalBoxes += (f['num_boxes'] as num?)?.toInt() ?? 0;
            totalWeight += (f['weight_kg'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Clean up aggregated strings
        cats = cats.isEmpty ? '' : cats.substring(0, cats.length - 3);
        uses = uses.isEmpty ? '' : uses.substring(0, uses.length - 3);

        final verified = data['verified_status'] == true;
        final verifiedAt = data['verified_at'] is Timestamp
            ? DateFormat('MMM d, yyyy hh:mm a')
            .format((data['verified_at'] as Timestamp).toDate())
            : 'N/A';

        final cardColor = index.isEven ? Colors.grey.shade50 : Colors.white;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
          elevation: 1,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
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
                        data['store_name'] ?? 'Unknown Store',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _verificationBadge(verified),
                  ],
                ),
                const Divider(height: 10, color: Colors.black12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Total boxes and weight displayed prominently
                      _detailPair('Boxes', '$totalBoxes', Colors.teal),
                      _detailPair('Weight (kg)', totalWeight.toStringAsFixed(
                          1), Colors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Additional metadata rows
                _metadataRow('Volunteer', data['user_name'] ?? 'N/A'),
                _metadataRow('Categories', cats.isEmpty ? 'N/A' : cats),
                _metadataRow('Use Cases', uses.isEmpty ? 'N/A' : uses),
                if (verified) _metadataRow('Verified At', verifiedAt),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper widget for displaying a label-value pair (e.g., Boxes: 10).
  Widget _detailPair(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  /// Helper widget for displaying a key-value row for metadata.
  Widget _metadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(child: Text(value,
              style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  /// Builds the main header section with title and CSV report buttons.
  Widget _buildReportHeader(BuildContext context) {
    return Card(
      color: Theme
          .of(context)
          .primaryColor,
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Delivery Analytics Dashboard",
              style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white54, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Button to download CSV report
                ElevatedButton.icon(
                  onPressed: () => _downloadCSVReport(context),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                // Button to email CSV report via SendGrid
                ElevatedButton.icon(
                  onPressed: () => _sendEmailReport(context),
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Email CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a standardized section header with an icon.
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepOrange, size: 24),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
      ),
      // Use StreamBuilder to listen for real-time updates from Firestore 'deliveries' collection
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('deliveries')
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error state
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // 3. No data state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportHeader(context),
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        'No delivery data found to generate charts/logs.'),
                  )),
                ],
              ),
            );
          }

          // 4. Data available: Process data for charts
          final docs = snapshot.data!.docs;
          Map<String, double> totals = {}; // Map to hold Category -> Total Weight

          // Aggregate total weight for each food category
          for (var doc in docs) {
            final data = doc.data();
            final list = data['food_data'] as List<dynamic>? ?? [];
            for (var f in list) {
              if (f is Map<String, dynamic>) {
                final cat = (f['category'] ?? f['Category'] ?? '').toString();
                if (cat.isNotEmpty) {
                  final weight = (f['weight_kg'] as num?)?.toDouble() ?? 0.0;
                  totals[cat] = (totals[cat] ?? 0) + weight;
                }
              }
            }
          }

          // 5. Build the UI with the fetched and processed data
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildReportHeader(context), // Header with download/email buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // --- Charts Section ---
                    _buildSectionHeader(
                    "Weight Distribution Charts", Icons.bar_chart),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                      children: [
                      _buildBarChart(totals), // Bar Chart (Weight by Category)
                  const SizedBox(height: 30),
                  _buildPieChart(totals), // Pie Chart (Weight Distribution) ],
                ]
                ),

              ),
              // --- Delivery Log Section ---
              _buildSectionHeader(
                  "Detailed Delivery Log", Icons.list_alt),
              _buildDeliveryList(docs), // List of individual deliveries
              const SizedBox(height: 20),
            ],
            ),
          ),
          ]),
          );
        },
      ),
    );
  }
}
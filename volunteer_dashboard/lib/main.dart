import 'package:flutter/material.dart';

void main() => runApp(const AdminDashboardApp());

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFD1E8C1), // Light green background
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '/': (context) => const DashboardPage(),
        '/schedule': (context) => const SchedulePage(),
      },
      initialRoute: '/',
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: const DashboardBody(),
      // FloatingActionButton removed as requested
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Expanded(child: InfoCard(label: 'Total Deliveries', value: '3')),
                  SizedBox(width: 18),
                  Expanded(child: InfoCard(label: 'Pending', value: '3')),
                  SizedBox(width: 18),
                  Expanded(child: InfoCard(label: 'Verified', value: '0')),
                  SizedBox(width: 18),
                  Expanded(child: InfoCard(label: 'Volunteers', value: '3')),
                  SizedBox(width: 18),
                  Expanded(child: InfoCard(label: 'Store Partners', value: '3')),
                  SizedBox(width: 18),
                  Expanded(child: InfoCard(label: 'Total Food (kg)', value: '60.0')),
                ],
              ),
              const SizedBox(height: 28),
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Deliveries'),
                        Tab(text: 'Analytics'),
                        Tab(text: 'Volunteers'),
                      ],
                    ),
                    SizedBox(
                      height: 350,
                      child: TabBarView(
                        children: [
                          DeliveryManagementTable(),
                          Center(child: Text('Analytics Page')),
                          Center(child: Text('Volunteers Page')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const InfoCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis)
          ],
        ),
      ),
    );
  }
}

class DeliveryManagementTable extends StatefulWidget {
  const DeliveryManagementTable({super.key});

  @override
  DeliveryManagementTableState createState() => DeliveryManagementTableState();
}

class DeliveryManagementTableState extends State<DeliveryManagementTable> {
  final List<Map<String, String>> deliveries = [
    {
      "id": "DEL1001",
      "store": "Farm Fresh",
      "foodType": "Organic Apples",
      "quantity": "10 kg",
      "status": "pending",
      "volunteer": "Shubham",
    },
    {
      "id": "DEL1002",
      "store": "Green Grocers",
      "foodType": "Leafy Greens",
      "quantity": "25 kg",
      "status": "verified",
      "volunteer": "Vizal",
    },
    {
      "id": "DEL1003",
      "store": "Whole Foods Market",
      "foodType": "Fresh Vegetables",
      "quantity": "15 kg",
      "status": "pending",
      "volunteer": "Tanya",
    },
  ];

  final List<String> volunteers = ["Shubham", "Vizal", "Tanya"];

  void assignVolunteer(int index, String? volunteer) {
    setState(() {
      deliveries[index]["volunteer"] = volunteer ?? "";
    });
  }

  void verifyDelivery(int index) {
    setState(() {
      deliveries[index]["status"] = "verified";
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Delivery Verified')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Store')),
          DataColumn(label: Text('Food Type')),
          DataColumn(label: Text('Quantity')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Volunteer')),
          DataColumn(label: Text('Actions')),
        ],
        rows: deliveries.asMap().entries.map((entry) {
          int idx = entry.key;
          Map<String, String> item = entry.value;
          return DataRow(cells: [
            DataCell(Text(item["id"]!)),
            DataCell(Text(item["store"]!)),
            DataCell(Text(item["foodType"]!)),
            DataCell(Text(item["quantity"]!)),
            DataCell(Text(item["status"]!)),
            DataCell(
              DropdownButton<String>(
                value: item["volunteer"]!.isEmpty ? null : item["volunteer"],
                hint: const Text('Assign'),
                items: volunteers
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (vol) => assignVolunteer(idx, vol),
              ),
            ),
            DataCell(
              ElevatedButton(
                onPressed: () => verifyDelivery(idx),
                child: const Text('Verify'),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Welcome Admin')),
          ListTile(
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          ListTile(
            title: const Text('Schedule'),
            onTap: () => Navigator.pushNamed(context, '/schedule'),
          ),
        ],
      ),
    );
  }
}

class AddItemsPage extends StatelessWidget {
  // Not needed, so replaced with a placeholder
  const AddItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Items')),
      body: const Center(
        child: Text('Add Items functionality removed.'),
      ),
    );
  }
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final schedule = [
      {
        "title": "Delivery Pickup",
        "time": "${today.year}-${today.month}-${today.day} 10:00"
      },
      {
        "title": "Store Meeting",
        "time": "${today.year}-${today.month}-${today.day} 14:00"
      },
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('User Schedule')),
      body: ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (ctx, idx) => ListTile(
          leading: const Icon(Icons.event),
          title: Text(schedule[idx]["title"]!),
          subtitle: Text(schedule[idx]["time"]!),
        ),
      ),
    );
  }
}

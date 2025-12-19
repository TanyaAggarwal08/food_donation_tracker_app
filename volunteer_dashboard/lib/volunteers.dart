import 'package:flutter/material.dart';

void main() => runApp(const VolunteerDashboardApp());

class VolunteerDashboardApp extends StatelessWidget {
  const VolunteerDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volunteer Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5FAFC),
      ),
      home: const VolunteerDashboardPage(),
    );
  }
}

class VolunteerDashboardPage extends StatefulWidget {
  const VolunteerDashboardPage({super.key});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  List<Map<String, dynamic>> deliveries = [];

  void _navigateAndAddDelivery(BuildContext context) async {
  final selectedStore = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const StoreSelectionPage()),
  );

  if (!context.mounted) return;

  if (selectedStore != null) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryDetailsPage(store: selectedStore, onAdd: (data) {
          if (!context.mounted) return;
          setState(() {
            deliveries.add(data);
          });
        }),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 26, top: 18),
            child: Card(
              elevation: 5,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  "Welcome back, user!",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8), color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: const Text(
              "Add Item",
              style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ),
          FloatingActionButton(
            tooltip: "Add Item",
            child: const Icon(Icons.add),
            onPressed: () => _navigateAndAddDelivery(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 20,
                spacing: 28,
                children: [
                  VolunteerStatusCard(
                    icon: Icons.access_time_outlined,
                    color: Colors.orange,
                    title: "Pending",
                    value: deliveries.where((d) => !d['completed']).length.toString(),
                    subtitle: "To be completed",
                  ),
                  VolunteerStatusCard(
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    title: "Completed",
                    value: deliveries.where((d) => d['completed']).length.toString(),
                    subtitle: "Verified deliveries",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Card(
                  color: const Color(0xFFF8F9FB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 1,
                  child: Container(
                    width: 370,
                    height: 410,
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Assigned Deliveries',
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'View and update your delivery tasks',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 40),
                        Expanded(
                          child: deliveries.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.inbox_outlined,
                                        size: 44, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text("No deliveries assigned yet",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 16)),
                                    SizedBox(height: 4),
                                    Text("Check back later for new tasks",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: deliveries.where((d) => !d['completed']).length,
                                  itemBuilder: (ctx, i) {
                                    final pendingDeliveries = deliveries.where((d) => !d['completed']).toList();
                                    final d = pendingDeliveries[i];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: ListTile(
                                        leading: const Icon(Icons.local_shipping,
                                            color: Colors.blue),
                                        title: Text(
                                            d['store'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                        subtitle: Text(
                                          "${d['productType']} • ${d['weight']}kg (${d['boxes']} boxes) → ${d['use']}",
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              d['completed'] = true;
                                            });
                                          },
                                          child: const Text('Complete'),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VolunteerStatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  const VolunteerStatusCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 255,
        height: 105,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const Spacer(),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 26)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))
          ],
        ),
      ),
    );
  }
}

class StoreSelectionPage extends StatelessWidget {
  const StoreSelectionPage({super.key});

  final List<String> stores = const [
    "TNT",
    "SAVE ON FOODS",
    "WALMART",
    "SAFEWAY",
    "SUPERSTORE",
    "NO FRILLS",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Store')),
      body: ListView.builder(
        itemCount: stores.length,
        itemBuilder: (context, index) {
          final store = stores[index];
          return ListTile(
            title: Text(store),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliveryDetailsPage(
                    store: store,
                    onAdd: (data) {
                      // This function can be a no-op here or handled differently
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DeliveryDetailsPage extends StatefulWidget {
  final String store;
  final Function(Map<String, dynamic>) onAdd;
  const DeliveryDetailsPage({super.key, required this.store, required this.onAdd});

  @override
  State<DeliveryDetailsPage> createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  String? productType;
  String weight = '';
  String boxes = '';
  String? useType;
  bool showSuccessMessage = false;

  final productTypes = [
    'Dairy',
    'Produce',
    'Meat',
    'Bakery',
    'Beverages',
    'Snacks',
    'Other'
  ];
  final uses = ['Charity', 'Farm'];

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onAdd({
        'store': widget.store,
        'productType': productType!,
        'weight': weight,
        'boxes': boxes,
        'use': useType!,
        'completed': false,
      });
      setState(() {
        showSuccessMessage = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Details for ${widget.store}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Product Type'),
                      isExpanded: true,
                      initialValue: productType,
                      items: productTypes
                          .map((pt) => DropdownMenuItem(value: pt, child: Text(pt)))
                          .toList(),
                      onChanged: (val) => setState(() => productType = val),
                      validator: (val) =>
                          val == null ? 'Select product type' : null,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter weight';
                        if (int.tryParse(v) == null) return 'Enter a valid integer';
                        if (int.parse(v) <= 0) return 'Must be > 0';
                        return null;
                      },
                      onChanged: (v) => weight = v,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Number of Boxes'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter box count';
                        if (int.tryParse(v) == null) return 'Enter a valid integer';
                        if (int.parse(v) <= 0) return 'Must be > 0';
                        return null;
                      },
                      onChanged: (v) => boxes = v,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Use For'),
                      isExpanded: true,
                      initialValue: useType,
                      items: uses
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) => setState(() => useType = val),
                      validator: (val) => val == null ? 'Select use' : null,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                        ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Add Item'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Go to Home'),
                        ),
                      ],
                    ),
                    if (showSuccessMessage)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'Item added successfully!',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

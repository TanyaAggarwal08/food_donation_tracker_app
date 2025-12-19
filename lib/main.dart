  import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
//

import 'services/auth_service.dart';
import 'services/NotificationService.dart';
import 'screens/role_selection.dart';
import 'screens/auth_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/volunteer/volunteer_page.dart';
import 'screens/store_owner/store_dashboard.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required for background messages
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FoodLinkApp());
}

class FoodLinkApp extends StatelessWidget {
  const FoodLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'FoodLink Society',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
        initialRoute: '/',
        routes: {
          '/': (_) => const RoleSelectionScreen(),
          '/auth': (_) => const AuthScreen(),
          // '/admin': (_) => const AdminDashboard(),
          // '/volunteer': (_) => const VolunteerPage(),
          // '/store': (_) => const StoreDashboard(),
        },

    );
  }
}

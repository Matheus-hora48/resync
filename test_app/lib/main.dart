import 'package:flutter/material.dart';
import 'package:resync/resync.dart';
import 'package:test_app/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Resync.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Offline First Example',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

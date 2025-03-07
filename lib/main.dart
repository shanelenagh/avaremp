import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'documents_screen.dart';
import 'download_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

void main()  {

  Storage().init().then((accentColor) {
    runApp(const MainApp());
  });

}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => Storage().settings.showIntro() ? const OnBoardingScreen() : const MainScreen(),
        '/download': (context) => const DownloadScreen(),
        '/documents': (context) => const DocumentsScreen(),
      },
      theme : ThemeData(
        brightness: Brightness.dark,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'audible_traffic_alerts.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  
  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  
  AudibleTrafficAlerts? alertPlayer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: const Center(
          child: Text("Play audio by pushing button below")
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: playIt,
          child: const Text("Play Audio")
        ),
      ),
    );
  }

  void playIt() async {
    AudibleTrafficAlerts? player = await AudibleTrafficAlerts.getAndStartAudibleTrafficAlerts(1.1);
    print("created audible alerts");
    player?.playSomeStuff();
    print("tried to play some stuff");
  }
}
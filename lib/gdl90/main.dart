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
  bool isAudioLoaded = false;

  @override
  void initState() {
    super.initState();
    AudibleTrafficAlerts.getAndStartAudibleTrafficAlerts().then((value)  { 
      alertPlayer = value;
      isAudioLoaded = true; 
      print("Audible alerts loaded");
      setState(() {}); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(!isAudioLoaded ? "Loading audio..." : "Play audio by pushing button below")
        ),
        floatingActionButton: isAudioLoaded ? FloatingActionButton(
          onPressed: playIt,
          child: const Text("Play Audio")
        ) : null,
      ),
    );
  }

  void playIt() async {
    //await alertPlayer?.playSomeStuff();
    print("tried to play some stuff");
  }
}
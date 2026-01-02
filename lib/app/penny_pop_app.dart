import 'package:flutter/material.dart';
import 'package:penny_pop_app/routing/app_router.dart';

class PennyPopApp extends StatelessWidget {
  const PennyPopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Penny Pop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}



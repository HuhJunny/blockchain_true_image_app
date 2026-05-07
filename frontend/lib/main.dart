import 'package:flutter/material.dart';
import 'page/home_page.dart';
import 'page/temp_login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Block Snap',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      // 앱 시작 화면을 임시 로그인 페이지로 설정
      initialRoute: '/login',

      routes: {'/login': (context) => const TempLoginPage()},
    );
  }
}

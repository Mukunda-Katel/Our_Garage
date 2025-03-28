import 'package:flutter/material.dart';
import 'package:flutter_1/pages/Honda.dart';
import 'package:flutter_1/pages/account_page.dart';
import 'package:flutter_1/pages/bajaj.dart';
import 'package:flutter_1/pages/bmw.dart';
import 'package:flutter_1/pages/bullet.dart';
import 'package:flutter_1/pages/ducati.dart';
import 'package:flutter_1/pages/duke.dart';
import 'package:flutter_1/pages/home_page.dart';
import 'package:flutter_1/pages/kawasaki.dart';
import 'package:flutter_1/pages/login_page.dart';
import 'package:flutter_1/pages/signup_page.dart';
import 'package:flutter_1/pages/suzuki.dart';
import 'package:flutter_1/pages/users_page.dart';
import 'package:flutter_1/pages/yamaha.dart';
import 'package:flutter_1/utils/routes.dart';
import 'package:flutter_1/widgets/Drawer.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: GoogleFonts.lato().fontFamily,
      ),
      darkTheme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      initialRoute: MyRoutes.loginRoute,
      routes: {
        // Default route for HomePage, mostly used at app startup
        MyRoutes.homeRoute: (context) {
          final Map<String, dynamic> args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final String username = args['username'] ?? '';
          final String email = args['email'] ?? '';
          return HomePage(username: username, email: email);
        },
        MyRoutes.loginRoute: (context) => const LoginPage(),
        MyRoutes.signupRoute: (context) => const SignupPage(),
        
        // Other routes that take arguments from navigation
        MyRoutes.bajajRoute: (context) {
          // Get arguments from route if available
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Bajaj(username: username, email: email);
        },
        
        MyRoutes.yamahaRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Yamaha(username: username, email: email);
        },
        
        MyRoutes.hondaRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Honda(username: username, email: email);
        },
        
        MyRoutes.dukeRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Duke(username: username, email: email);
        },
        
        MyRoutes.bulletRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Bullet(username: username, email: email);
        },
        
        MyRoutes.SuzukiRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Suzuki(username: username, email: email);
        },
        
        MyRoutes.bmwRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return BMW(username: username, email: email);
        },
        
        MyRoutes.kawasakiRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Kawasaki(username: username, email: email);
        },
        
        MyRoutes.ducatiRoute: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] as String? ?? '';
          final email = args?['email'] as String? ?? '';
          return Ducati(username: username, email: email);
        },
        
        // Account route
        MyRoutes.profileRoute: (context) {
          final Map<String, dynamic> args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final String username = args['username'] ?? '';
          final String email = args['email'] ?? '';
          return AccountPage(username: username, email: email);
        },
        MyRoutes.usersRoute: (context) {
          final Map<String, dynamic> args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final String username = args['username'] ?? '';
          final String email = args['email'] ?? '';
          return UsersPage(username: username, email: email);
        },
      },
    );
  }
}
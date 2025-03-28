import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_1/utils/routes.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class MyDrawer extends StatefulWidget {
  final String username;
  final String email;

  const MyDrawer({super.key, required this.username, required this.email});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  File? _profileImage;
  bool _isLoading = true;  // Add loading state
  int _userCount = 0;  // User count for badge

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile image when dependencies change (like navigation)
    _loadProfileImage();
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      if (mounted) {
        setState(() {
          _userCount = registeredUsers.length;
        });
      }
    } catch (e) {
      // Remove debug print
    }
  }

  Future<void> _loadProfileImage() async {
    if (!mounted) return;  // Safety check
    
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? imagePath = prefs.getString('${widget.username}_profile_pic');
      
      if (imagePath != null) {
        File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          if (mounted) {  // Check again before setState
            setState(() {
              _profileImage = imageFile;
              _isLoading = false;
            });
          }
          // Remove debug print
        } else {
          // Remove debug print
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        // Remove debug print
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      // Remove debug print
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              accountName: Text(widget.username), // Use the passed username
              accountEmail: Text(widget.email.isNotEmpty ? widget.email : "No email provided"), // Handle empty email
              currentAccountPicture: _isLoading
                  ? const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: CircularProgressIndicator(),
                    )
                  : CircleAvatar(
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider
                          : const AssetImage("assets/images/Login.png"),
                    ),
            ),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.home, color: Colors.black),
            title: const Text("Home", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushReplacementNamed(context, MyRoutes.homeRoute, arguments: {
                'username': widget.username,
                'email': widget.email,
              });
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.profile_circled, color: Colors.black),
            title: const Text("Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushReplacementNamed(
                context, 
                MyRoutes.profileRoute,
                arguments: {'username': widget.username, 'email': widget.email}
              );
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.person_3_fill, color: Colors.black),
            title: const Text("All Accounts", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            trailing: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$_userCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              Navigator.pushReplacementNamed(
                context, 
                MyRoutes.usersRoute,
                arguments: {'username': widget.username, 'email': widget.email}
              );
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right),
            title: const Text("Log Out", style: TextStyle(color: Color.fromARGB(255, 77, 59, 53), fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pushReplacementNamed(context, MyRoutes.loginRoute);
            },
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_1/widgets/Drawer.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class UsersPage extends StatefulWidget {
  final String username;
  final String email;

  const UsersPage({super.key, required this.username, required this.email});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      List<Map<String, dynamic>> users = [];
      
      // Get all keys to find ALL user accounts directly by looking at user_ keys
      Set<String> allKeys = prefs.getKeys();
      
      // Find ALL user credentials (keys that start with 'user_')
      Set<String> userKeys = allKeys.where((key) => key.startsWith('user_')).toSet();
      
      if (userKeys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user accounts found. Try creating some sample accounts.'),
            backgroundColor: Colors.orange,
          )
        );
      }
      
      // Process each user from user_ keys
      for (String userKey in userKeys) {
        // Extract username from the key (remove 'user_' prefix)
        String username = userKey.substring(5); // 'user_'.length = 5
        
        // Get email for this user
        String email = prefs.getString('email_$username') ?? '';
        
        // Get bio for this user (if available)
        String bioKey = '${username}_bio';
        String bio = prefs.getString(bioKey) ?? 'Bio is empty';
        
        // Get profile image path for this user (if available)
        String profilePicKey = '${username}_profile_pic';
        String? profileImagePath = prefs.getString(profilePicKey);
        
        // Add user to the list
        users.add({
          'username': username,
          'email': email,
          'bio': bio,
          'profileImage': profileImagePath
        });
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load users: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final username = user['username'].toString().toLowerCase();
      final bio = user['bio'].toString().toLowerCase();
      
      return username.contains(query) || bio.contains(query);
    }).toList();
  }

  // Function to add a demo user
  Future<void> _addDemoUser() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Generate a random number to make the username unique
      final random = DateTime.now().millisecondsSinceEpoch % 10000;
      final username = 'demo_user_$random';
      final email = 'demo$random@example.com';
      final bio = 'This is a demo user created for testing on ${DateTime.now().toString().substring(0, 16)}';
      
      // Store user data
      await prefs.setString('user_$username', 'demo123'); // Simple demo password
      await prefs.setString('email_$username', email);
      await prefs.setString('${username}_bio', bio);
      
      // Add to registered users list
      List<String> registeredUsers = prefs.getStringList('registered_users') ?? [];
      registeredUsers.add(username);
      await prefs.setStringList('registered_users', registeredUsers);
      
      // Reload users list
      await _loadUsers();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demo user "$username" created successfully'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create demo user: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  Future<void> _createSampleUsers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Create sample users directly
      await prefs.setString('user_john_doe', 'password123');
      await prefs.setString('email_john_doe', 'john@example.com');
      await prefs.setString('john_doe_bio', 'Motorcycle enthusiast from New York');
      
      await prefs.setString('user_jane_smith', 'password123');
      await prefs.setString('email_jane_smith', 'jane@example.com');
      await prefs.setString('jane_smith_bio', 'Professional racer with 5+ years experience');
      
      await prefs.setString('user_mike_johnson', 'password123');
      await prefs.setString('email_mike_johnson', 'mike@example.com');
      await prefs.setString('mike_johnson_bio', 'Bio is empty');
      
      // Reload the users list
      await _loadUsers();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample users created successfully'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create sample users: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Accounts"),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh accounts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading accounts',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search accounts',
                          hintText: 'Enter username or bio',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    
                    // Results count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Found ${_filteredUsers.length} ${_filteredUsers.length == 1 ? 'account' : 'accounts'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    
                    // Users list
                    Expanded(
                      child: _users.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.person_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No accounts found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Try signing up some users first',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadUsers,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredUsers.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching accounts found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: _filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    final String username = user['username'] ?? '';
                                    final String email = user['email'] ?? '';
                                    final String bio = user['bio'] ?? 'Bio is empty';
                                    final String? profileImagePath = user['profileImage'];
                                    final bool isCurrentUser = username == widget.username;
                                    
                                    return Card(
                                      elevation: 3,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: isCurrentUser ? BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Profile Image
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundImage: profileImagePath != null && File(profileImagePath).existsSync()
                                                      ? FileImage(File(profileImagePath)) as ImageProvider
                                                      : const AssetImage("assets/images/Login.png"),
                                                ),
                                                const SizedBox(width: 12),
                                                // Username
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        username,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                      if (isCurrentUser)
                                                        Container(
                                                          margin: const EdgeInsets.only(left: 8),
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: const Text(
                                                            'You',
                                                            style: TextStyle(
                                                              color: Colors.blue,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 20),
                                            // Bio section
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(
                                                  width: 70,
                                                  child: Text(
                                                    "Bio:",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    bio,
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
      drawer: MyDrawer(username: widget.username, email: widget.email),
    );
  }
} 
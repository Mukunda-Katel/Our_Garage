import 'package:flutter/material.dart';
import 'package:flutter_1/utils/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dart:convert';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  String _debugInfo = ''; // For debugging connection issues

  @override
  void initState() {
    super.initState();
    _bioController.text = "Hello! I am a new user.";
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugInfo = '';
    });

    try {
      String username = _usernameController.text;
      String password = _passwordController.text;
      String email = _emailController.text;
      String bio = _bioController.text;
      bool isRegistered = false;

      // First try to register with the backend API
      try {
        print("Attempting to register with backend API...");
        final response = await ApiService.registerUser(
          username,
          password,
          email,
        );

        print("API Response status code: ${response.statusCode}");
        print("API Response body: ${response.body}");
        
        // Store debug info
        setState(() {
          _debugInfo = "API Status: ${response.statusCode}\nBody: ${response.body}";
        });

        if (response.statusCode == 201 || response.statusCode == 200) {
          print("Successfully registered user with the backend API");
          isRegistered = true;
          
          // Try to parse the response for additional details
          try {
            final Map<String, dynamic> responseData = json.decode(response.body);
            if (responseData.containsKey('id') || responseData.containsKey('user_id')) {
              print("User ID from API: ${responseData['id'] ?? responseData['user_id']}");
            }
          } catch (e) {
            print("Error parsing response JSON: $e");
          }
        } else {
          print("API registration failed with status code: ${response.statusCode}");
          setState(() {
            _errorMessage = "Server error: ${response.statusCode}";
            if (response.body.isNotEmpty) {
              try {
                final Map<String, dynamic> errorData = json.decode(response.body);
                if (errorData.containsKey('error')) {
                  _errorMessage = errorData['error'];
                } else if (errorData.containsKey('detail')) {
                  _errorMessage = errorData['detail'];
                }
              } catch (e) {
                _errorMessage = "Server error: ${response.reasonPhrase}";
              }
            }
          });
        }
      } catch (e) {
        print("API registration failed, proceeding with local registration: $e");
        setState(() {
          _debugInfo = "API Error: $e";
        });
      }
      
      // Regardless of API success, also store locally for app functionality
      try {
        // Store the user in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        
        // Check if username already exists
        bool userExists = prefs.containsKey('user_$username');
        if (userExists) {
          setState(() {
            _errorMessage = 'Username already exists. Please choose another one.';
            _isLoading = false;
          });
          return;
        }
        
        // Store user data
        await prefs.setString('user_$username', password);
        await prefs.setString('email_$username', email);
        await prefs.setString('${username}_bio', bio);
        
        // Get existing registered users list or create a new one
        List<String> registeredUsers = prefs.getStringList('registered_users') ?? [];
        
        // Add the new user to the list if not already present
        if (!registeredUsers.contains(username)) {
          registeredUsers.add(username);
          // Save the updated list
          await prefs.setStringList('registered_users', registeredUsers);
        }
        
        print('User registered locally: $username');
        print('Updated registered users list: $registeredUsers');
        
        // Set registration flag to indicate success at least locally
        isRegistered = true;
      } catch (e) {
        print("Error during local registration: $e");
        if (!isRegistered) {
          setState(() {
            _errorMessage = 'Registration failed. Please try again.';
            _isLoading = false;
          });
          return;
        }
      }

      if (isRegistered) {
        // Navigate to login page after successful registration
        if (mounted) {
          Navigator.pushReplacementNamed(context, MyRoutes.loginRoute);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please login.'))
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again later.';
        _debugInfo = "Error: $e";
      });
      print('Error during registration: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Sign up to get started",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Debug info for developers
              if (_debugInfo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[200],
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Debug Info (API Connection):", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                        Text(_debugInfo, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        hintText: "Enter username",
                        labelText: "Username",
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Username cannot be empty";
                        } else if (value.length < 3) {
                          return "Username must be at least 3 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: "Enter email",
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Email cannot be empty";
                        } else if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                          return "Please enter a valid email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Enter password",
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Password cannot be empty";
                        } else if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Confirm password",
                        labelText: "Confirm Password",
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please confirm your password";
                        } else if (value != _passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "Tell others about yourself...",
                        labelText: "Bio",
                        prefixIcon: Icon(Icons.edit),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.deepPurple,
                              minimumSize: const Size(150, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, MyRoutes.loginRoute);
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
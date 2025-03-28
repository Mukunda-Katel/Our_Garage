// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_1/utils/routes.dart'; // Import routes
import 'api_service.dart'; // Ensure ApiService is public
import 'dart:convert'; // For jsonDecode
import 'home_page.dart'; // Import the HomePage
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // Password change controllers
  final _passwordChangeFormKey = GlobalKey<FormState>();
  final TextEditingController _changeUsernameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false; // Initialize as false
  bool _isLogin = true;
  String _debugInfo = ''; // For debugging connection issues

 void _registerUser() async {
  setState(() {
    _isLoading = true;
    _debugInfo = '';
  });

  try {
    print("Registering user...");
    String username = _usernameController.text;
    String password = _passwordController.text;
    String email = _emailController.text;
    bool isRegistered = false;
    
    try {
      // Try to register with the API
      print("Attempting to register with backend API...");
      final response = await ApiService.registerUser(
        username,
        password,
        email,
      );

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      setState(() {
        _debugInfo = "API Status: ${response.statusCode}\nBody: ${response.body}";
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        isRegistered = true;
        print("Successfully registered user with the backend API");
        
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
        _showErrorDialog("Server error: ${response.statusCode}. ${response.reasonPhrase ?? ''}");
      }
    } catch (e) {
      print("API registration failed, proceeding with local registration: $e");
      setState(() {
        _debugInfo = "API Error: $e";
      });
    }
    
    // Always register locally regardless of API success/failure
    try {
      // Store user credentials in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if username already exists
      if (prefs.containsKey('user_$username')) {
        _showErrorDialog("Username already exists. Please choose another one.");
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Save user credentials
      await prefs.setString('user_$username', password);
      await prefs.setString('email_$username', email);
      
      // Set a default bio for the new user
      await prefs.setString('${username}_bio', 'Hello! I am a new user.');
      
      // Get existing registered users list or create a new one
      List<String> registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      // Add the new user to the list if not already present
      if (!registeredUsers.contains(username)) {
        registeredUsers.add(username);
        // Save the updated list
        await prefs.setStringList('registered_users', registeredUsers);
      }
      
      print('User registered: $username');
      print('Updated registered users list: $registeredUsers');
      
      // Set registration success flag
      isRegistered = true;
      
      print("User registered locally: $username, $email");
    } catch (e) {
      print("Error during local registration: $e");
      if (!isRegistered) {
        _showErrorDialog("Registration failed. Please try again.");
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }
    
    if (isRegistered) {
      // Show success dialog
      _showSuccessDialog("Registration successful! Please log in.");

      // Switch back to the login view
      setState(() {
        _isLogin = true;
      });

      // Clear the form fields
      _usernameController.clear();
      _passwordController.clear();
      _emailController.clear();
    }
  } catch (e) {
    print("Error during registration: $e");
    _showErrorDialog("An error occurred. Please check your connection and try again.");
    setState(() {
      _debugInfo = "Error: $e";
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

void _loginUser() async {
  setState(() {
    _isLoading = true;
    _debugInfo = '';
  });

  try {
    print("Logging in user...");
    bool loginSuccess = false;
    String username = _usernameController.text;
    String email = "";
    
    try {
      // First try to log in using the API
      print("Attempting to login with backend API...");
      final response = await ApiService.loginUser(
        username,
        _passwordController.text,
      );

      print("API Response status code: ${response.statusCode}");
      print("API Response body: ${response.body}");
      
      setState(() {
        _debugInfo = "API Status: ${response.statusCode}\nBody: ${response.body}";
      });

      if (response.statusCode == 200) {
        // API login successful
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        
        // Get email with better fallback
        if (responseBody.containsKey('email') && responseBody['email'] != null) {
          email = responseBody['email'];
        } else if (_emailController.text.isNotEmpty) {
          email = _emailController.text;
        }
        
        loginSuccess = true;
        print("API Login successful - Username: $username, Email: $email");
      } else {
        print("API login failed with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("API login failed, trying local authentication: $e");
      setState(() {
        _debugInfo = "API Error: $e";
      });
    }
    
    // If API login failed, try local authentication
    if (!loginSuccess) {
      print("Trying local authentication via SharedPreferences");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if user exists in SharedPreferences
      String? storedPassword = prefs.getString('user_$username');
      
      if (storedPassword != null && storedPassword == _passwordController.text) {
        loginSuccess = true;
        // Get email from SharedPreferences
        email = prefs.getString('email_$username') ?? "";
        print("Local login successful - Username: $username, Email: $email");
      }
    }
    
    if (loginSuccess) {
      // Navigate to HomePage after successful login
      Navigator.pushReplacementNamed(
        context, 
        MyRoutes.homeRoute,
        arguments: {
          'username': username,
          'email': email,
        },
      );
    } else {
      _showErrorDialog("Login failed. Please check your username and password.");
    }
  } catch (e) {
    print("Error during login: $e");
    _showErrorDialog("An error occurred. Please check your connection and try again.");
    setState(() {
      _debugInfo = "Error: $e";
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

void _showPasswordChangeDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _passwordChangeFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _changeUsernameController,
              decoration: const InputDecoration(
                hintText: "Enter your username",
                labelText: "Username",
              ),
              validator: (value) {
                if (value!.isEmpty) {
                  return "Username cannot be empty";
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                hintText: "Enter your current password",
                labelText: "Current Password",
              ),
              obscureText: true,
              validator: (value) {
                if (value!.isEmpty) {
                  return "Current password cannot be empty";
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                hintText: "Enter your new password",
                labelText: "New Password",
              ),
              obscureText: true,
              validator: (value) {
                if (value!.isEmpty) {
                  return "New password cannot be empty";
                } else if (value.length < 8) {
                  return "Password must be at least 8 characters long";
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(ctx).pop();
          },
        ),
        TextButton(
          child: const Text('Change Password'),
          onPressed: () {
            if (_passwordChangeFormKey.currentState!.validate()) {
              Navigator.of(ctx).pop();
              _changePassword();
            }
          },
        ),
      ],
    ),
  );
}

void _changePassword() async {
  setState(() {
    _isLoading = true;
  });

  try {
    print("Changing password...");
    final response = await ApiService.changePassword(
      _changeUsernameController.text,
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    print("Response status code: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      // Clear the controllers
      _changeUsernameController.clear();
      _currentPasswordController.clear();
      _newPasswordController.clear();
      
      // Show success dialog
      _showSuccessDialog("Password changed successfully! Please log in with your new password.");
    } else {
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      _showErrorDialog(responseBody['error'] ?? "Password change failed. Please try again.");
    }
  } catch (e) {
    print("Error during password change: $e");
    _showErrorDialog("An error occurred. Please check your connection and try again.");
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('An Error Occurred!'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success!'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              "assets/images/Login.png",
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 25),
            Text(
              _isLogin ? "Welcome, LogIn here" : "Welcome, SignUp here",
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 65, 60, 62),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(70.50),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        hintText: "Enter your username",
                        labelText: "Username",
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Username cannot be empty";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        hintText: "Enter your password",
                        labelText: "Password",
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Password cannot be empty";
                        } else if (value.length < 8) {
                          return "Password must be at least 8 characters long";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: "Enter your email",
                        labelText: "Email",
                      ),
                      validator: (value) {
                        if (!_isLogin && value!.isEmpty) {
                          return "Email cannot be empty";
                        } else if (!_isLogin && !value!.contains('@')) {
                          return "Enter a valid email address";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                if (_isLogin) {
                                  _loginUser();
                                } else {
                                  _registerUser();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(130, 50),
                            ),
                            child: Text(_isLogin ? "Log in" : "Sign up"),
                          ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        if (_isLogin) {
                          // Navigate to signup page
                          Navigator.pushReplacementNamed(context, MyRoutes.signupRoute);
                        } else {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        }
                      },
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Sign up"
                            : "Already have an account? Log in",
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
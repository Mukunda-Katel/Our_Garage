import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Base URLs for different environments - CHOOSE THE CORRECT ONE FOR YOUR SETUP
  
  // For Android Emulator - points to your computer's localhost Django server
  static const String localEmulatorUrl = "http://10.0.2.2:8000/api/";
  
  // For physical devices - REPLACE "YOUR_COMPUTER_IP" with your actual computer's IP address 
  // For example: "http://192.168.1.5:8000/api/"
  static const String localDeviceUrl = "http://YOUR_COMPUTER_IP:8000/api/";
  
  // For deployed/production backend
  static const String productionUrl = "https://your-production-url.com/api/";
  
  // ********** IMPORTANT: CHANGE THIS TO MATCH YOUR SETUP **********
  // 1. Use localEmulatorUrl if testing on Android Emulator
  // 2. Use localDeviceUrl with YOUR computer's IP if using physical device
  // 3. Use productionUrl if connecting to deployed backend
  static const String baseUrl = localEmulatorUrl;

  // Register a new user
  static Future<http.Response> registerUser(String username, String password, String email) async {
    try {
      print("Sending registration request to: ${baseUrl}register/");
      final response = await http.post(
        Uri.parse('${baseUrl}register/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
          'email': email,
        }),
      );
      print("Registration response received: ${response.statusCode}");
      print("Registration response body: ${response.body}");
      return response;
    } catch (e) {
      print("Registration request failed: $e");
      throw Exception('Failed to register user: $e');
    }
  }

  // Login a user
  static Future<http.Response> loginUser(String username, String password) async {
    try {
      print("Sending login request to: ${baseUrl}login/");
      final response = await http.post(
        Uri.parse('${baseUrl}login/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );
      print("Login response received: ${response.statusCode}");
      print("Login response body: ${response.body}");
      return response;
    } catch (e) {
      print("Login request failed: $e");
      throw Exception('Failed to login user: $e');
    }
  }

  // Change password for a user
  static Future<http.Response> changePassword(String username, String currentPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}change-password/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }
  
  // Get user profile picture
  static Future<http.Response> getProfilePicture(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}profile-picture/$username/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to get profile picture: $e');
    }
  }

  // Upload profile picture
  static Future<http.Response> uploadProfilePicture(String username, File imageFile) async {
    try {
      print("Starting profile picture upload for user: $username");
      print("Image file path: ${imageFile.path}");
      
      // Create a multipart request
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${baseUrl}upload-profile-picture/'),
      );
      
      // Add fields
      request.fields['username'] = username;
      
      // Get the file extension
      String fileExtension = imageFile.path.split('.').last.toLowerCase();
      print("File extension: $fileExtension");
      
      // Add the file
      var multipartFile = await http.MultipartFile.fromPath(
        'image', 
        imageFile.path,
        contentType: MediaType('image', fileExtension),
      );
      request.files.add(multipartFile);
      print("File added to request, length: ${multipartFile.length}");
      
      // Send the request
      print("Sending request to server...");
      var streamedResponse = await request.send();
      
      // Convert to a regular response
      var response = await http.Response.fromStream(streamedResponse);
      print("Response received: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      return response;
    } catch (e) {
      print("Error in uploadProfilePicture: $e");
      throw Exception('Failed to upload profile picture: $e');
    }
  }
}
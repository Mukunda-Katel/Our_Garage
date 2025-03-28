import 'package:flutter/material.dart';
import 'package:flutter_1/widgets/Drawer.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountPage extends StatefulWidget {
  final String username;
  final String email;

  const AccountPage({super.key, required this.username, required this.email});

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _bio = "";
  final TextEditingController _bioController = TextEditingController();
  bool _isEditingBio = false;

  @override
  void initState() {
    super.initState();
    // Debug prints to see if email is being received
    print("AccountPage - Username: ${widget.username}");
    print("AccountPage - Email: ${widget.email}");
    _loadProfilePicture();
    _loadBio();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadBio() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String bio = prefs.getString('${widget.username}_bio') ?? "No bio yet. Tap to add your bio.";
      
      setState(() {
        _bio = bio;
        _bioController.text = bio;
      });
    } catch (e) {
      print("Error loading bio: $e");
    }
  }

  Future<void> _saveBio(String bio) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('${widget.username}_bio', bio);
      
      setState(() {
        _bio = bio;
        _isEditingBio = false;
      });
    } catch (e) {
      print("Error saving bio: $e");
    }
  }

  Future<void> _loadProfilePicture() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load profile picture path from shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? imagePath = prefs.getString('${widget.username}_profile_pic');
      
      if (imagePath != null) {
        File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          setState(() {
            _selectedImage = imageFile;
          });
          print("Profile picture loaded from: $imagePath");
        }
      }
    } catch (e) {
      print("Error loading profile picture: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compress image to reduce size
      );
      
      if (pickedFile != null) {
        // Save image to app's documents directory
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/${widget.username}_profile.jpg';
        
        // Copy picked image to app's directory
        final File savedImage = await File(pickedFile.path).copy(path);
        
        // Save path to shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('${widget.username}_profile_pic', savedImage.path);
        
        setState(() {
          _selectedImage = savedImage;
        });
        
        _showSuccessDialog("Profile picture updated successfully");
      }
    } catch (e) {
      print("Error picking image: $e");
      _showErrorDialog("Failed to pick image: $e");
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.cyanAccent,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _selectedImage != null 
                        ? FileImage(_selectedImage!) as ImageProvider
                        : const AssetImage("assets/images/Login.png"),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _showImageSourceOptions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "My Bio",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: Icon(_isEditingBio ? Icons.check : Icons.edit),
                          onPressed: () {
                            if (_isEditingBio) {
                              _saveBio(_bioController.text);
                            } else {
                              setState(() {
                                _isEditingBio = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    _isEditingBio
                        ? TextField(
                            controller: _bioController,
                            maxLines: 5,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              hintText: "Tell others about yourself...",
                              border: OutlineInputBorder(),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _bio,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Account Information",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text("Username", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(widget.username, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 5),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        widget.email.isNotEmpty ? widget.email : "No email provided", 
                        style: const TextStyle(fontSize: 16)
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Account Settings",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: const Text("Change Profile Picture"),
                      subtitle: const Text("Upload a new profile picture"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showImageSourceOptions,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text("Logout"),
                      subtitle: const Text("Sign out from your account"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: MyDrawer(username: widget.username, email: widget.email),
    );
  }
} 
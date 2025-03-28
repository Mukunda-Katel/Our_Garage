import 'package:flutter/material.dart';
import 'package:flutter_1/utils/routes.dart';
import 'package:flutter_1/widgets/Drawer.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String email;

  const HomePage({super.key, required this.username, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Define bike data in a structured format
  final List<Map<String, dynamic>> _bikes = [
    {
      'name': 'Bajaj',
      'image': 'assets/images/bajaj.png',
      'route': MyRoutes.bajajRoute,
    },
    {
      'name': 'Duke',
      'image': 'assets/images/ktm.png',
      'route': MyRoutes.dukeRoute,
    },
    {
      'name': 'Suzuki',
      'image': 'assets/images/suzuki.png',
      'route': MyRoutes.SuzukiRoute,
    },
    {
      'name': 'Bullet',
      'image': 'assets/images/bullet.png',
      'route': MyRoutes.bulletRoute,
    },
    {
      'name': 'Honda',
      'image': 'assets/images/hero.png',
      'route': MyRoutes.hondaRoute,
    },
    {
      'name': 'Yamaha',
      'image': 'assets/images/yamaha.png',
      'route': MyRoutes.yamahaRoute,
    },
    {
      'name': 'BMW',
      'image': 'assets/images/bmw.png',
      'route': MyRoutes.bmwRoute,
    },
    {
      'name': 'Kawasaki',
      'image': 'assets/images/kawasaki.png',
      'route': MyRoutes.kawasakiRoute,
    },
    {
      'name': 'Ducati',
      'image': 'assets/images/ducati.png',
      'route': MyRoutes.ducatiRoute,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Filter bikes based on search query
  List<Map<String, dynamic>> get _filteredBikes {
    if (_searchQuery.isEmpty) {
      return _bikes;
    }
    return _bikes.where((bike) => 
      bike['name'].toLowerCase().contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Get arguments if passed during navigation
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    // Use arguments if available, otherwise use widget properties
    final username = args?['username'] as String? ?? widget.username;
    final email = args?['email'] as String? ?? widget.email;
    
    // Debug prints to verify username and email
    print("HomePage - Username: $username");
    print("HomePage - Email: $email");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Our Garage"),
        backgroundColor: Colors.cyanAccent,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bikes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredBikes.length} bikes found',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          
          // Bike grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _filteredBikes.isEmpty
                ? const Center(
                    child: Text(
                      'No bikes found matching your search',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredBikes.length,
                    itemBuilder: (context, index) {
                      final bike = _filteredBikes[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context, 
                              bike['route'],
                              arguments: {'username': username, 'email': email}
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Image.asset(
                                  bike['image'], 
                                  height: 80,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  bike['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      drawer: MyDrawer(username: username, email: email),
    );
  }
}
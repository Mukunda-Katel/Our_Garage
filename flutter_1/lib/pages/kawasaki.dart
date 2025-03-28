import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_1/widgets/Drawer.dart';
import 'dart:async';
import 'package:flutter_1/services/video_upload_service.dart';

class Kawasaki extends StatefulWidget {
  final String username;
  final String email;

  const Kawasaki({super.key, this.username = '', this.email = ''});

  @override
  KawasakiState createState() => KawasakiState();
}

class KawasakiState extends State<Kawasaki> {
  late VideoPlayerController _controller;
  List<Map<String, dynamic>> videos = [];
  int? _currentVideoIndex;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  static const String _storageKey = 'kawasaki_videos_v3';

  double _playbackSpeed = 1.0;
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _loadVideos().then((_) {
      _recoverMissingVideos();
    });
  }

  Future<void> _loadVideos() async {
    try {
      setState(() => _isLoading = true);
      
      final defaultVideos = [
        {
          'url': 'assets/videos/kawasaki1.mp4',
          'thumbnail': 'assets/images/kawasaki.png',
          'title': 'Kawasaki Ninja H2',
          'isAsset': true,
          'isDefault': false,
        },
      ];

      final prefs = await SharedPreferences.getInstance();
      final savedVideos = prefs.getString(_storageKey);
      
      if (savedVideos != null && savedVideos.isNotEmpty) {
        try {
          final List<dynamic> decodedVideos = jsonDecode(savedVideos);
          final List<Map<String, dynamic>> loadedVideos = [];
          
          // Create fresh maps instead of using Map.from() to avoid _Map type issues
          for (var video in decodedVideos) {
            // Create a completely new map with proper types
            Map<String, dynamic> videoMap = {
              'url': video['url'] ?? '',
              'thumbnail': video['thumbnail'] ?? 'assets/images/kawasaki.jpg',
              'title': video['title'] ?? 'Untitled Video',
              'isAsset': video['isAsset'] ?? false,
              'isDefault': video['isDefault'] ?? true,
            };
            
            // Add backendUrl if it exists
            if (video.containsKey('backendUrl') && video['backendUrl'] != null) {
              videoMap['backendUrl'] = video['backendUrl'];
            }
            
            loadedVideos.add(videoMap);
          }

          setState(() {
            videos = [...defaultVideos, ...loadedVideos];
            _isLoading = false;
          });
          return;
        } catch (e) {
          debugPrint('Error decoding saved videos: $e');
          // Continue to use default videos
        }
      }
      
      setState(() {
        videos = defaultVideos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() {
        videos = [
          {
            'url': 'assets/videos/kawasaki1.mp4',
            'thumbnail': 'assets/images/kawasaki.png',
            'title': 'Kawasaki Ninja H2',
            'isAsset': true,
            'isDefault': false,
          },
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveVideos() async {
    try {
      // Create a list to store only user-uploaded videos (non-asset videos)
      final List<Map<String, dynamic>> userVideos = [];
      
      // Filter out only the non-asset videos
      for (var video in videos) {
        if (video['isAsset'] == false) {
          // Create a completely new map with primitive values
          Map<String, dynamic> videoMap = {
            'url': video['url'].toString(),
            'thumbnail': video['thumbnail'].toString(),
            'title': video['title'].toString(),
            'isAsset': false,
            'isDefault': true,
          };
          
          // Add backendUrl if it exists
          if (video.containsKey('backendUrl') && video['backendUrl'] != null) {
            videoMap['backendUrl'] = video['backendUrl'].toString();
          }
          
          userVideos.add(videoMap);
        }
      }
      
      // Convert to a JSON-safe format first
      final List<Map<String, Object>> jsonSafeVideos = userVideos
          .map((video) => Map<String, Object>.from(video))
          .toList();
      
      // Use jsonEncode with the JSON-safe list
      final String jsonString = jsonEncode(jsonSafeVideos);
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving videos: $e');
    }
  }

  Future<void> _uploadVideo() async {
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null || !mounted) return;

      String? title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter video title'),
          content: TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Video title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _titleController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (title == null || title.isEmpty) return;
      _titleController.clear();

      // Validate and get video file
      final videoFile = File(pickedFile.path);
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${pickedFile.path}');
      }

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading video to server...')),
      );

      // Try to upload to backend first
      String? backendUrl;
      try {
        // Use real upload (uncomment when Django server is ready)
        // backendUrl = await VideoUploadService.uploadVideo(videoFile, title);
        
        // For testing, use mock upload
        backendUrl = await VideoUploadService.mockUploadVideo(videoFile, title);
      } catch (e) {
        debugPrint('Backend upload failed: $e');
        // Continue with local upload even if backend fails
      }
      
      // Save video locally regardless of backend result
      setState(() {
        videos.add({
          'url': pickedFile.path,
          'thumbnail': 'assets/images/kawasaki.jpg',
          'title': title,
          'isAsset': false,
          'isDefault': true,
          'backendUrl': backendUrl,
        });
      });

      await _saveVideos();
      
      if (!mounted) return;
      if (backendUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully to server and saved locally')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved locally only (server upload was skipped or failed)')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading video: $e')),
      );
    }
  }

  Future<void> _deleteVideo(int index) async {
    if (videos[index]['isAsset']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default videos')),
      );
      return;
    }

    setState(() {
      videos.removeAt(index);
      if (_currentVideoIndex == index) {
        _currentVideoIndex = null;
        _controller.dispose();
      } else if (_currentVideoIndex != null && _currentVideoIndex! > index) {
        _currentVideoIndex = _currentVideoIndex! - 1;
      }
    });

    await _saveVideos();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _playVideo(int index) async {
    if (_currentVideoIndex != null) {
      _controller.pause();
      _controller.dispose();
    }

    setState(() => _isLoading = true);
    _currentVideoIndex = index;
    
    try {
      // Use the service to get the appropriate controller (backend if available, local if not)
      _controller = await VideoUploadService.getVideoPlayerController(videos[index]);

      // If we reach here, the controller is initialized
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      _toggleFullScreen();
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenVideoPlayer(
            controller: _controller,
            playbackSpeed: _playbackSpeed,
            playbackSpeeds: _playbackSpeeds,
            onSpeedChanged: (speed) {
              setState(() => _playbackSpeed = speed);
            },
            toggleFullScreen: _toggleFullScreen,
            isFullScreen: _isFullScreen,
          ),
        ),
      );
      
      if (_isFullScreen) {
        _toggleFullScreen();
      }
      
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load video: $error')),
      );
    }
  }

  Future<void> _recoverMissingVideos() async {
    final videosToCheck = List<Map<String, dynamic>>.from(videos);
    bool hasChanges = false;
    
    for (int i = 0; i < videosToCheck.length; i++) {
      final video = videosToCheck[i];
      
      // Skip asset videos
      if (video['isAsset'] == true) continue;
      
      // Check if local file exists
      final File videoFile = File(video['url']);
      if (!videoFile.existsSync() && video.containsKey('backendUrl') && video['backendUrl'] != null) {
        // Show recovering message
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovering video "${video['title']}" from cloud...')),
        );
        
        // File is missing but we have a backend URL
        debugPrint('Local video file missing, will use backend URL: ${video['backendUrl']}');
        
        // Mark that the video is only available on the backend
        setState(() {
          videos[i] = Map<String, dynamic>.from(video);
          videos[i]['localFileAvailable'] = false;
        });
        
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveVideos();
    }
  }

  @override
  void dispose() {
    if (_currentVideoIndex != null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kawasaki Videos"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _uploadVideo,
            tooltip: 'Upload Video',
          ),
        ],
      ),
      drawer: MyDrawer(username: widget.username, email: widget.email),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : videos.isEmpty
              ? const Center(child: Text('No videos available'))
              : ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return GestureDetector(
                      onTap: () => _playVideo(index),
                      child: Card(
                        margin: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 16/9,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  video['isAsset']
                                      ? Image.asset(
                                          video['thumbnail'],
                                          fit: BoxFit.cover,
                                        )
                                      : video['isDefault'] == true
                                          ? Image.asset(
                                              video['thumbnail'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.grey.shade300,
                                                child: const Icon(Icons.play_circle_outline, size: 50),
                                              ),
                                            )
                                          : Image.file(
                                              File(video['thumbnail']),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.grey.shade300,
                                                child: const Icon(Icons.play_circle_outline, size: 50),
                                              ),
                                            ),
                                  const Icon(
                                    Icons.play_circle_fill,
                                    size: 50,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: Text(video['title']),
                              subtitle: Text(
                                video['isAsset'] ? 'Default Video' : 'Uploaded Video',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!video['isAsset'] && 
                                      video.containsKey('backendUrl') && 
                                      video['backendUrl'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Tooltip(
                                        message: 'Available on cloud',
                                        child: Icon(
                                          Icons.cloud_done,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  if (!video['isAsset'])
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteVideo(index),
                                      color: Colors.red,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final double playbackSpeed;
  final List<double> playbackSpeeds;
  final Function(double) onSpeedChanged;
  final Function toggleFullScreen;
  final bool isFullScreen;

  const FullScreenVideoPlayer({
    super.key,
    required this.controller,
    required this.playbackSpeed,
    required this.playbackSpeeds,
    required this.onSpeedChanged,
    required this.toggleFullScreen,
    required this.isFullScreen,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.play();
    _startHideControlsTimer();
    
    // Set the playback speed
    widget.controller.setPlaybackSpeed(widget.playbackSpeed);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
            if (_showControls) {
              _startHideControlsTimer();
            } else {
              _hideControlsTimer?.cancel();
            }
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            if (_showControls)
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              widget.isFullScreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              widget.toggleFullScreen();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Video progress slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ValueListenableBuilder(
                        valueListenable: widget.controller,
                        builder: (context, VideoPlayerValue value, child) {
                          final position = value.position;
                          final duration = value.duration;
                          
                          return Column(
                            children: [
                              Slider(
                                value: position.inMilliseconds.toDouble(),
                                min: 0.0,
                                max: duration.inMilliseconds.toDouble(),
                                onChanged: (value) {
                                  final newPosition = Duration(milliseconds: value.toInt());
                                  widget.controller.seekTo(newPosition);
                                  _startHideControlsTimer();
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Playback controls
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                            onPressed: () {
                              final newPosition = widget.controller.value.position - const Duration(seconds: 10);
                              widget.controller.seekTo(newPosition);
                              _startHideControlsTimer();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              widget.controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: () {
                              widget.controller.value.isPlaying
                                  ? widget.controller.pause()
                                  : widget.controller.play();
                              _startHideControlsTimer();
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                            onPressed: () {
                              final newPosition = widget.controller.value.position + const Duration(seconds: 10);
                              widget.controller.seekTo(newPosition);
                              _startHideControlsTimer();
                            },
                          ),
                          PopupMenuButton<double>(
                            onSelected: (speed) {
                              widget.onSpeedChanged(speed);
                              widget.controller.setPlaybackSpeed(speed);
                              _startHideControlsTimer();
                            },
                            itemBuilder: (context) => widget.playbackSpeeds
                                .map((speed) => PopupMenuItem<double>(
                                      value: speed,
                                      child: Text('${speed}x', 
                                        style: TextStyle(
                                          fontWeight: widget.playbackSpeed == speed 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.playbackSpeed}x',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 
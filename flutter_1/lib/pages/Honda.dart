import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_1/services/video_upload_service.dart';

class Honda extends StatefulWidget {
  const Honda({super.key, required String username, required String email});

  @override
  HondaState createState() => HondaState();
}

class HondaState extends State<Honda> {
  late VideoPlayerController _controller;
  List<Map<String, dynamic>> videos = [];
  int? _currentVideoIndex;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final String _storageKey = 'honda_videos_v3';

  double _playbackSpeed = 1.0;
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Get device ID first so it's available for the rest of the app
    await _getDeviceId();
    
    // Then load videos
    await _loadVideos();
    
    // Finally try to load backend videos
    await _loadBackendVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    
    final defaultVideos = [
      {
        'url': 'assets/videos/honda1.mp4',
        'thumbnail': 'assets/images/hero.png',
        'title': 'Honda Introduction',
        'isAsset': true,
        'isDefault': false,
      },
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVideos = prefs.getString(_storageKey);
      
      if (savedVideos != null) {
        final List<dynamic> decodedVideos = jsonDecode(savedVideos);
        final List<Map<String, dynamic>> loadedVideos = [];
        
        // Create fresh maps instead of using Map.from() to avoid _Map type issues
        for (var video in decodedVideos) {
          // Create a completely new map with proper types
          Map<String, dynamic> videoMap = {
            'url': video['url'] ?? '',
            'thumbnail': video['thumbnail'] ?? 'assets/images/hero.png',
            'title': video['title'] ?? 'Untitled Video',
            'isAsset': video['isAsset'] ?? false,
            'isDefault': video['isDefault'] ?? true,
          };
          
          loadedVideos.add(videoMap);
        }
        
        setState(() {
          videos = [...defaultVideos, ...loadedVideos];
          _isLoading = false;
        });
      } else {
        setState(() {
          videos = defaultVideos;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() {
        videos = defaultVideos;
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
            'url': video['url']?.toString() ?? '',
            'thumbnail': video['thumbnail']?.toString() ?? 'assets/images/hero.png',
            'title': video['title']?.toString() ?? 'Untitled Video',
            'isAsset': false,
            'isDefault': true,
          };
          
          // Preserve backend URL if present
          if (video['backendUrl'] != null) {
            videoMap['backendUrl'] = video['backendUrl'].toString();
          }
          
          // Preserve uploader information
          if (video['uploadedBy'] != null) {
            videoMap['uploadedBy'] = video['uploadedBy'].toString();
          }
          
          userVideos.add(videoMap);
          
          // Make sure to store shared video info for cross-device access
          if (video['backendUrl'] != null && video['title'] != null) {
            await VideoUploadService.storeSharedVideoInfo(
              video['title'].toString(),
              video['url']?.toString() ?? '',
              video['backendUrl'].toString(),
              video['uploadedBy']?.toString() ?? await _getDeviceId(),
            );
          }
        }
      }
      
      // Convert to a JSON-safe format
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

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading video to server...')),
      );

      // Get the video file
      final videoFile = File(pickedFile.path);
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${pickedFile.path}');
      }

      // Upload to backend
      String? backendUrl = await VideoUploadService.uploadVideo(videoFile, title);
      
      // If backend upload fails, try to use mock backend
      if (backendUrl == null) {
        backendUrl = await VideoUploadService.mockUploadVideo(videoFile, title);
      }

      // Create a new map with simple primitive values
      final Map<String, Object> newVideo = {
        'url': pickedFile.path,
        'thumbnail': 'assets/images/hero.png',
        'title': title,
        'isAsset': false,
        'isDefault': true,
        if (backendUrl != null) 'backendUrl': backendUrl,
      };

      setState(() {
        videos.add(newVideo);
      });

      await _saveVideos();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(backendUrl != null 
            ? 'Video uploaded to server successfully' 
            : 'Video saved locally only')),
      );
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
      // Get controller from service which handles both local/asset and backend videos
      _controller = await VideoUploadService.getVideoPlayerController(videos[index]);

      await _controller.initialize();
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      // Start in full screen mode
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
      
      // Restore orientation when returning
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

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Honda Videos"),
        backgroundColor: Colors.red, // Honda's characteristic color
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _uploadVideo,
            tooltip: 'Upload Video',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing videos from all devices...')),
              );
              _loadBackendVideos();
            },
            tooltip: 'Refresh Videos from All Devices',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : videos.isEmpty
              ? const Center(child: Text('No videos available'))
              : ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final bool isRemoteVideo = video['backendUrl'] != null && 
                        (video['url'] == null || video['url'].toString().startsWith('mock_'));
                    final bool isFromOtherDevice = video['uploadedBy'] != null && 
                        video['uploadedBy'].toString() != 'unknown' &&
                        !_isVideoFromThisDevice(video);
                    
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
                                            ),
                                  const Icon(
                                    Icons.play_circle_fill,
                                    size: 50,
                                    color: Colors.white70,
                                  ),
                                  if (isFromOtherDevice)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'From another device',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: Text(video['title']),
                              subtitle: Text(
                                video['isAsset'] 
                                    ? 'Default Video' 
                                    : isFromOtherDevice
                                        ? 'Shared Video'
                                        : 'Uploaded Video',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isRemoteVideo && !video['isAsset'])
                                    IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () => _downloadVideo(index),
                                      color: Colors.blue,
                                      tooltip: 'Download for offline viewing',
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

  /// Loads videos from the backend API
  Future<void> _loadBackendVideos() async {
    try {
      if (!mounted) return;
      
      setState(() => _isLoading = true);
      
      final backendVideos = await VideoUploadService.fetchVideos();
      
      if (backendVideos != null && backendVideos.isNotEmpty && mounted) {
        // Create a list to track videos to auto-download
        final List<Map<String, dynamic>> videosToDownload = [];
        
        for (var video in backendVideos) {
          // Check if this video already exists in our list
          final existingIndex = videos.indexWhere((v) => 
              v['backendUrl'] != null && 
              v['backendUrl'] == video['backendUrl']);
              
          if (existingIndex == -1) {
            // This is a new video, add it to our list
            setState(() {
              videos.add(video);
            });
            
            // If from another device and has no local URL, mark for download
            if (!_isVideoFromThisDevice(video) && 
                (video['url'] == null || video['url'].toString().isEmpty)) {
              videosToDownload.add(video);
            }
          }
        }
        
        // Save updated videos list
        await _saveVideos();
        
        // Auto-download the first video from another device (to avoid flooding)
        if (videosToDownload.isNotEmpty) {
          // Find this video's index in our main list
          final videoToDownload = videosToDownload.first;
          final downloadIndex = videos.indexWhere((v) => 
              v['backendUrl'] != null && 
              v['backendUrl'] == videoToDownload['backendUrl']);
              
          if (downloadIndex >= 0) {
            // Start downloading this video
            _autoDownloadVideo(downloadIndex);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading backend videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading shared videos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// Automatically download a video without UI indicators
  Future<void> _autoDownloadVideo(int index) async {
    try {
      final video = videos[index];
      if (video['backendUrl'] == null) {
        return; // No backend URL available for this video
      }
      
      // Download the video quietly
      final localPath = await VideoUploadService.downloadVideo(
        video['backendUrl'].toString(), 
        video['title'].toString()
      );
      
      if (localPath != null && mounted) {
        // Update the video entry with the local path
        setState(() {
          videos[index] = {
            ...video,
            'url': localPath,
          };
        });
        
        // Save videos list with updated local path
        await _saveVideos();
        
        // Show a success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded "${video['title']}" for offline viewing')),
          );
        }
      }
    } catch (e) {
      debugPrint('Auto-download error: $e');
    }
  }

  /// Check if a video was uploaded from this device
  bool _isVideoFromThisDevice(Map<String, dynamic> video) {
    if (!video.containsKey('uploadedBy') || video['uploadedBy'] == null) {
      return true; // Default to true if no info
    }
    
    final String uploaderId = video['uploadedBy'].toString();
    final String? deviceId = _deviceId;
    
    return deviceId != null && uploaderId.contains(deviceId);
  }
  
  // Cached device ID
  String? _deviceId;
  
  /// Gets the device ID to determine which device uploaded the video
  Future<String> _getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }
      
      _deviceId = deviceId;
      return deviceId;
    } catch (e) {
      _deviceId = 'unknown_device';
      return 'unknown_device';
    }
  }
  
  /// Downloads a video from the backend for offline viewing
  Future<void> _downloadVideo(int index) async {
    try {
      setState(() => _isLoading = true);
      
      final video = videos[index];
      if (video['backendUrl'] == null) {
        throw Exception('No backend URL available for this video');
      }
      
      // Show downloading message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading video for offline viewing...')),
      );
      
      // Download the video
      final localPath = await VideoUploadService.downloadVideo(
        video['backendUrl'].toString(), 
        video['title'].toString()
      );
      
      if (localPath != null) {
        // Update the video entry with the local path
        setState(() {
          videos[index] = {
            ...video,
            'url': localPath,
          };
        });
        
        // Save videos list with updated local path
        await _saveVideos();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video downloaded successfully')),
        );
      } else {
        throw Exception('Failed to download video');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading video: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// The FullScreenVideoPlayer class remains exactly the same
class FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final double playbackSpeed;
  final List<double> playbackSpeeds;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback toggleFullScreen;
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
  late bool _isPlaying;
  bool _showControls = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    _duration = widget.controller.value.duration;
    _position = widget.controller.value.position;
    
    widget.controller.addListener(_videoListener);
    widget.controller.setPlaybackSpeed(widget.playbackSpeed);
    widget.controller.play();
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
        _duration = widget.controller.value.duration;
        _position = widget.controller.value.position;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? widget.controller.play() : widget.controller.pause();
    });
  }

  void _changeSpeed(double speed) {
    widget.controller.setPlaybackSpeed(speed);
    widget.onSpeedChanged(speed);
  }

  void _seekTo(Duration position) {
    widget.controller.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleControls,
                          child: Container(
                            color: Colors.transparent,
                            child: Center(
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            Expanded(
                              child: Slider(
                                value: _position.inSeconds.toDouble(),
                                min: 0,
                                max: _duration.inSeconds.toDouble(),
                                onChanged: (value) {
                                  _seekTo(Duration(seconds: value.toInt()));
                                },
                                onChangeEnd: (value) {
                                  _seekTo(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                            Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            PopupMenuButton<double>(
                              icon: const Icon(Icons.speed, color: Colors.white),
                              itemBuilder: (context) => widget.playbackSpeeds
                                  .map((speed) => PopupMenuItem<double>(
                                        value: speed,
                                        child: Text('${speed}x'),
                                      ))
                                  .toList(),
                              onSelected: _changeSpeed,
                            ),
                            IconButton(
                              icon: Icon(
                                widget.isFullScreen 
                                    ? Icons.fullscreen_exit 
                                    : Icons.fullscreen,
                                color: Colors.white,
                              ),
                              onPressed: widget.toggleFullScreen,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
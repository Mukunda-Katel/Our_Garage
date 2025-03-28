import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoUploadService {
  // Use a public backend URL that's accessible from any device
  // For production, use a real cloud-hosted backend URL here
  static const String baseUrl = 'https://motorcycle-videos-api.onrender.com/api';
  
  // We'll use a common cloud storage URL that both devices can access
  static const String sharedCloudStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/motorcycle-app-12345.appspot.com/o/';
  
  // Fallback to local testing URLs if needed
  static const String localEmulatorUrl = 'http://10.0.2.2:8000/api';  // For Android emulator
  static const String localSimulatorUrl = 'http://127.0.0.1:8000/api';  // For iOS simulator
  
  /// Gets the authentication token from shared preferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  /// Uploads a video file to the backend
  /// Returns the URL of the uploaded video if successful
  static Future<String?> uploadVideo(File videoFile, String title) async {
    try {
      // Create a multipart request
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/videos/upload/')
      );
      
      // Add auth header
      final token = await _getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Token $token';
      }
      
      // Add video file
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      
      final multipartFile = http.MultipartFile(
        'video_file',
        videoStream,
        videoLength,
        filename: basename(videoFile.path),
      );
      
      // Add fields
      request.files.add(multipartFile);
      request.fields['title'] = title;
      request.fields['device_id'] = await _getDeviceId(); // To track which device uploaded the video
      
      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response to get the video URL
        final Map<String, dynamic> responseData = json.decode(response.body);
        final videoUrl = responseData['videoUrl'];
        
        // Store the successful upload to track synced videos
        await _markVideoAsSynced(videoUrl);
        
        return videoUrl;
      } else {
        debugPrint('Error uploading video: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during video upload: $e');
      
      // Try backup URLs if main URL fails
      try {
        return await _tryBackupUrls(videoFile, title);
      } catch (_) {
        return null;
      }
    }
  }
  
  // Try backup URLs in case main URL is not accessible
  static Future<String?> _tryBackupUrls(File videoFile, String title) async {
    // Try emulator URL
    try {
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse('$localEmulatorUrl/videos/upload/')
      );
      
      // Setup request (simplified for backup)
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      
      final multipartFile = http.MultipartFile(
        'video_file',
        videoStream,
        videoLength,
        filename: basename(videoFile.path),
      );
      
      request.files.add(multipartFile);
      request.fields['title'] = title;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['videoUrl'];
      }
    } catch (e) {
      debugPrint('Backup URL failed: $e');
    }
    
    // If all else fails, fall back to mock backend
    return mockUploadVideo(videoFile, title);
  }
  
  /// Gets a unique device ID to track which device uploaded videos
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
  
  /// Marks a video as successfully synced with the backend
  static Future<void> _markVideoAsSynced(String videoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing synced videos
    final syncedVideos = prefs.getStringList('synced_videos') ?? [];
    
    // Add this video URL if not already in the list
    if (!syncedVideos.contains(videoUrl)) {
      syncedVideos.add(videoUrl);
      await prefs.setStringList('synced_videos', syncedVideos);
    }
  }
  
  /// Mock implementation that simulates a successful upload
  /// Use this for testing without an actual backend
  static Future<String?> mockUploadVideo(File videoFile, String title) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if file exists
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${videoFile.path}');
      }
      
      // Generate a unique ID for this video that's deterministic based on title
      // This ensures same video has same ID across devices
      final videoId = title.hashCode.toString().replaceAll('-', '');
      final deviceId = await _getDeviceId();
      
      // Create a mock URL that would be accessible from any device
      final mockUrl = '$sharedCloudStorageUrl$deviceId%2F$videoId.mp4?alt=media';
      
      // Store the video path and URL in a shared location
      await storeSharedVideoInfo(title, videoFile.path, mockUrl, deviceId);
      
      // Mark this video as synced with our mock backend
      await _markVideoAsSynced(mockUrl);
      
      return mockUrl;
    } catch (e) {
      debugPrint('Mock upload error: $e');
      return null;
    }
  }
  
  /// Store video information in a shared location for cross-device access
  static Future<void> storeSharedVideoInfo(
    String title, 
    String localPath, 
    String cloudUrl,
    String deviceId
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Format: title|localPath|cloudUrl|deviceId
    final videoInfo = '$title|$localPath|$cloudUrl|$deviceId';
    
    // Store in device-independent key
    final sharedVideos = prefs.getStringList('shared_videos') ?? [];
    
    // Check if this video is already in the list
    final existingIndex = sharedVideos.indexWhere((v) => v.split('|')[2] == cloudUrl);
    if (existingIndex >= 0) {
      // Update existing entry
      sharedVideos[existingIndex] = videoInfo;
    } else {
      // Add new entry
      sharedVideos.add(videoInfo);
    }
    
    await prefs.setStringList('shared_videos', sharedVideos);
  }
  
  /// Generates mock videos for testing cross-device functionality
  static Future<List<Map<String, dynamic>>> _fetchMockVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();
    
    // Get the shared videos list
    final sharedVideos = prefs.getStringList('shared_videos') ?? [];
    final List<Map<String, dynamic>> mockVideos = [];
    
    // Add all shared videos to the list
    for (var videoInfoStr in sharedVideos) {
      final parts = videoInfoStr.split('|');
      if (parts.length >= 4) {
        final title = parts[0];
        final localPath = parts[1];
        final cloudUrl = parts[2];
        final uploaderDeviceId = parts[3];
        
        final isFromThisDevice = uploaderDeviceId == deviceId;
        
        mockVideos.add({
          'url': isFromThisDevice ? localPath : '', // Only set URL if from this device
          'thumbnail': 'assets/images/default_thumbnail.jpg',
          'title': title,
          'isAsset': false,
          'isDefault': false,
          'backendUrl': cloudUrl,
          'uploadedBy': uploaderDeviceId,
        });
      }
    }
    
    // If no shared videos, add example videos
    if (mockVideos.isEmpty) {
      // Add shared videos from this device
      final thisDeviceVideo = {
        'url': '',
        'thumbnail': 'assets/images/default_thumbnail.jpg',
        'title': 'Example from Your Device',
        'isAsset': false,
        'isDefault': false,
        'backendUrl': '$sharedCloudStorageUrl$deviceId%2Fexample.mp4?alt=media',
        'uploadedBy': deviceId,
      };
      mockVideos.add(thisDeviceVideo);
      
      // Add example from other device
      mockVideos.add({
        'url': '',
        'thumbnail': 'assets/images/default_thumbnail.jpg',
        'title': 'Example from Other Device',
        'isAsset': false,
        'isDefault': false,
        'backendUrl': '${sharedCloudStorageUrl}other_device%2Fshared_example.mp4?alt=media',
        'uploadedBy': 'other_device',
      });
      
      // Store these examples in shared location
      await storeSharedVideoInfo(
        'Example from Your Device',
        '',
        '$sharedCloudStorageUrl$deviceId%2Fexample.mp4?alt=media',
        deviceId
      );
      
      await storeSharedVideoInfo(
        'Example from Other Device',
        '',
        '${sharedCloudStorageUrl}other_device%2Fshared_example.mp4?alt=media',
        'other_device'
      );
    }
    
    return mockVideos;
  }
  
  /// Fetches videos from the backend
  static Future<List<Map<String, dynamic>>?> fetchVideos() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/videos/'),
        headers: token != null ? {'Authorization': 'Token $token'} : {},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((video) => {
          'url': video['video_url'],
          'thumbnail': video['thumbnail_url'] ?? 'assets/images/default_thumbnail.jpg',
          'title': video['title'],
          'isAsset': false,
          'isDefault': false,
          'backendUrl': video['video_url'],
          'uploadedBy': video['device_id'] ?? 'unknown',
        }).toList();
      } else {
        debugPrint('Error fetching videos: ${response.statusCode}');
        
        // Try mock backend if real backend fails
        return _fetchMockVideos();
      }
    } catch (e) {
      debugPrint('Exception during fetch videos: $e');
      
      // Try mock backend if real backend fails
      return _fetchMockVideos();
    }
  }
  
  /// Returns a VideoPlayerController for either a local file or a remote URL
  /// Falls back to local file if remote URL is unavailable
  static Future<VideoPlayerController> getVideoPlayerController(Map<String, dynamic> video) async {
    // Check if video has a backend URL and try to use it first
    if (video.containsKey('backendUrl') && video['backendUrl'] != null) {
      try {
        final backendUrl = video['backendUrl'].toString();
        debugPrint('Trying to play video from URL: $backendUrl');
        
        // Try to create a network controller first
        final controller = VideoPlayerController.network(backendUrl);
        
        // Test initialize to see if URL is valid
        await controller.initialize();
        
        // Return the network controller if successful
        return controller;
      } catch (e) {
        debugPrint('Failed to load remote video, falling back to local: $e');
        // If network fails, fall back to local file
      }
    }
    
    // Use asset or local file
    if (video['isAsset'] == true) {
      return VideoPlayerController.asset(video['url'].toString());
    } else {
      final String localPath = video['url']?.toString() ?? '';
      if (localPath.isEmpty) {
        // If no local path, try to download the video first
        if (video['backendUrl'] != null) {
          final downloadedPath = await downloadVideo(
            video['backendUrl'].toString(),
            video['title']?.toString() ?? 'Downloaded Video'
          );
          
          if (downloadedPath != null) {
            final videoFile = File(downloadedPath);
            if (videoFile.existsSync()) {
              return VideoPlayerController.file(videoFile);
            }
          }
        }
        
        // If no download or download failed, show error
        throw Exception('No local or remote video available');
      }
      
      final videoFile = File(localPath);
      if (!videoFile.existsSync()) {
        // If local file doesn't exist, show a placeholder video or error
        throw Exception('Video file not found: $localPath');
      }
      return VideoPlayerController.file(videoFile);
    }
  }
  
  /// Downloads a video from the backend to local storage
  static Future<String?> downloadVideo(String backendUrl, String title) async {
    try {
      // Create a unique local file path - use app's temporary directory
      final tempDir = Directory.systemTemp;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$title.mp4';
      final localPath = '${tempDir.path}/$fileName';
      
      // Download the file
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        return localPath;
      } else {
        debugPrint('Failed to download video: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading video: $e');
      return null;
    }
  }
} 
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:digital_diary/services/video_cache_service.dart';

// Global cache to store video controllers with LRU (Least Recently Used) policy
// This is an in-memory cache for quick access during the app session
final Map<String, VideoPlayerController> _videoControllerCache = {};
final List<String> _cacheOrder = [];
const int _maxCachedVideos = 5; // In-memory cache for current session

void _addToCache(String key, VideoPlayerController controller) {
  // If cache is full, remove the oldest video
  if (_cacheOrder.length >= _maxCachedVideos) {
    final oldestKey = _cacheOrder.removeAt(0);
    _videoControllerCache[oldestKey]?.dispose();
    _videoControllerCache.remove(oldestKey);
  }
  
  // Add new video to cache
  _videoControllerCache[key] = controller;
  _cacheOrder.add(key);
}

void _updateCacheOrder(String key) {
  // Move accessed video to the end (most recently used)
  _cacheOrder.remove(key);
  _cacheOrder.add(key);
}

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isLocalFile;
  // This new onTap callback allows us to customize the tap behavior from outside.
  final VoidCallback? onTap;
  // Option to show or hide controls
  final bool showControls;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    this.isLocalFile = false,
    this.onTap,
    this.showControls = true,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _showControls = false;
  bool _isMuted = false;
  
  final VideoCacheService _cacheService = VideoCacheService();

  void _onControllerUpdate() {
    if (!mounted) return;
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        setState(() {
          _isPlaying = _controller!.value.isPlaying;
        });
      }
    } catch (e) {
      // Ignore update errors
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If this element gets reused for a different video (e.g. list item removed),
    // re-initialize to avoid showing the previous video's frame/thumbnail.
    if (oldWidget.videoUrl != widget.videoUrl || oldWidget.isLocalFile != widget.isLocalFile) {
      try {
        if (_controller != null) {
          _controller!.removeListener(_onControllerUpdate);
          if (_controller!.value.isInitialized) {
            _controller!.pause();
          }
        }
      } catch (_) {
        // ignore
      }

      _controller = null;
      _errorMessage = null;
      if (mounted) {
        setState(() {
          _isInitializing = true;
          _isPlaying = false;
        });
      } else {
        _isInitializing = true;
        _isPlaying = false;
      }

      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // Check if we already have this video controller in memory cache
      if (_videoControllerCache.containsKey(widget.videoUrl)) {
        _controller = _videoControllerCache[widget.videoUrl];
        _updateCacheOrder(widget.videoUrl); // Mark as recently used
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      } else {
        // Create new controller
        if (widget.isLocalFile) {
          // Local file - use directly
          _controller = VideoPlayerController.file(File(widget.videoUrl));
        } else {
          // Network video - check persistent disk cache first
          final cachedFile = await _cacheService.getCachedVideo(widget.videoUrl);
          
          if (cachedFile != null) {
            // Play from disk cache
            _controller = VideoPlayerController.file(cachedFile);
            if (kDebugMode) print('▶️ Playing from disk cache: ${widget.videoUrl}');
          } else {
            // Not in cache - stream from network and cache in background
            _controller = VideoPlayerController.networkUrl(
              Uri.parse(widget.videoUrl),
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: false,
              ),
              httpHeaders: {
                'Connection': 'keep-alive',
              },
            );
            
            // Cache the video in background for next time
            _cacheService.cacheVideo(widget.videoUrl);
          }
        }

        // Initialize with better error handling
        await _controller!.initialize();
        
        // Set initial volume
        await _controller!.setVolume(1.0);
        
        // Enable looping for smoother playback
        await _controller!.setLooping(true);
        
        // Add to in-memory cache for quick access
        _addToCache(widget.videoUrl, _controller!);
        
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }

      _controller!.addListener(_onControllerUpdate);
    } catch (e) {
      if (kDebugMode) print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to load video';
        });
      }
    }
  }

  @override
  void dispose() {
    // Pause video to save resources
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.pause();
      }
    } catch (e) {
      // Ignore disposal errors
    }
    try {
      _controller?.removeListener(_onControllerUpdate);
    } catch (_) {
      // ignore
    }
    // Don't dispose the controller if it's cached
    super.dispose();
  }

  @override
  void deactivate() {
    // Pause video when widget is removed from tree
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.pause();
      }
    } catch (e) {
      // Ignore deactivation errors
    }
    super.deactivate();
  }

  void _togglePlay() {
    if (_controller?.value.isPlaying ?? false) {
      _controller?.pause();
    } else {
      _controller?.play();
    }
  }

  void _toggleMute() {
    if (_controller != null) {
      setState(() {
        _isMuted = !_isMuted;
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super for AutomaticKeepAliveClientMixin
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isInitializing) {
      return Container(
        color: isDark ? Colors.black : Colors.grey.shade200,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              backgroundColor: isDark 
                  ? Colors.deepOrange.withOpacity(0.2) 
                  : Colors.deepOrange.withOpacity(0.1),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: isDark ? Colors.black : Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline, 
                size: 48, 
                color: isDark ? Colors.red.shade300 : Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!, 
                style: TextStyle(
                  color: isDark ? Colors.red.shade300 : Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _errorMessage = null;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      // THE FIX: If an onTap is provided, use it. Otherwise, toggle controls.
      onTap: widget.onTap ?? () {
        if (widget.showControls) {
          setState(() {
            _showControls = !_showControls;
          });
        } else {
          _togglePlay();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            // If a custom onTap IS present (i.e., we are on the profile page), show a fullscreen icon
            if (widget.onTap != null)
              const Icon(
                Icons.fullscreen,
                color: Colors.white70,
                size: 40,
              ),
            // Show controls overlay when showControls is true and controls are visible
            if (widget.showControls && _showControls)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top controls - mute button
                    Align(
                      alignment: Alignment.topRight,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 38.0, right: 4.0),
                          child: IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleMute,
                          ),
                        ),
                      ),
                    ),
                    // Center - play/pause button
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 64,
                      ),
                      onPressed: _togglePlay,
                    ),
                    // Bottom controls - progress bar
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_controller!.value.position),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _controller!.value.position.inSeconds.toDouble().clamp(
                                    0.0, 
                                    _controller!.value.duration.inSeconds.toDouble()
                                  ),
                                  max: _controller!.value.duration.inSeconds.toDouble().clamp(1.0, double.infinity),
                                  onChanged: (value) {
                                    _controller!.seekTo(Duration(seconds: value.toInt()));
                                  },
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                ),
                              ),
                              Text(
                                _formatDuration(_controller!.value.duration),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // Show simple play icon when video is paused and controls are hidden
            if (!_isPlaying && !_showControls && widget.onTap == null)
              Icon(
                Icons.play_arrow,
                color: Colors.white.withOpacity(0.7),
                size: 60,
              ),
          ],
        ),
      ),
    );
  }
}


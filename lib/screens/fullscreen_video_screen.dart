import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullscreenVideoScreen extends StatefulWidget {
  final String videoUrl;

  const FullscreenVideoScreen({super.key, required this.videoUrl});

  @override
  State<FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<FullscreenVideoScreen> {
  @override
  void initState() {
    super.initState();
    // Set preferred orientations and system UI for better fullscreen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore system UI and orientation when leaving fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Restore system UI and orientation when user presses back
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
          children: [
            Center(
              child: VideoPlayerItem(
                key: ValueKey('fullscreen_${widget.videoUrl}'),
                videoUrl: widget.videoUrl,
                showControls: true,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
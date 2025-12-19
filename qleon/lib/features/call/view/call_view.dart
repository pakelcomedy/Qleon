import 'package:flutter/material.dart';

class CallView extends StatefulWidget {
  const CallView({super.key});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackground(),
            _buildTopBar(context),
            _buildCallControls(context),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// BACKGROUND (Avatar / Video Placeholder)
  /// =============================================================
  Widget _buildBackground() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircleAvatar(
            radius: 64,
            backgroundImage: NetworkImage(
              'https://i.pravatar.cc/300?img=11',
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Andi Wijaya',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Calling...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// TOP BAR
  /// =============================================================
  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// CALL CONTROLS
  /// =============================================================
  Widget _buildCallControls(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: 'Mute',
                isActive: _isMuted,
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                },
              ),
              _CallButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Speaker',
                isActive: _isSpeakerOn,
                onTap: () {
                  setState(() => _isSpeakerOn = !_isSpeakerOn);
                },
              ),
              _CallButton(
                icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                label: 'Video',
                isActive: _isVideoOn,
                onTap: () {
                  setState(() => _isVideoOn = !_isVideoOn);
                },
              ),
            ],
          ),
          const SizedBox(height: 28),
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// CALL BUTTON
/// =============================================================
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isActive ? Colors.white : Colors.white24,
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

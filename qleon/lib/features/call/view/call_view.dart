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
  void initState() {
    super.initState();
    _isSpeakerOn = false;
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;

      /// FORCE LOUDSPEAKER WHEN VIDEO CALL
      if (_isVideoOn) {
        _isSpeakerOn = true;
      }
    });
  }

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
  /// BACKGROUND (VOICE / VIDEO PLACEHOLDER)
  /// =============================================================
  Widget _buildBackground() {
    if (_isVideoOn) {
      /// VIDEO CALL PLACEHOLDER
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Video Stream',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 16,
          ),
        ),
      );
    }

    /// VOICE CALL UI
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.call,
            size: 72,
            color: Colors.white54,
          ),
          SizedBox(height: 20),
          Text(
            'Andi Wijaya',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
      bottom: 28,
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
                onTap: _isVideoOn
                    ? null // disable manual toggle when VC
                    : () {
                        setState(
                          () => _isSpeakerOn = !_isSpeakerOn,
                        );
                      },
              ),
              _CallButton(
                icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                label: 'Video',
                isActive: _isVideoOn,
                onTap: _toggleVideo,
              ),
            ],
          ),
          const SizedBox(height: 28),
          FloatingActionButton(
            backgroundColor: Colors.red,
            elevation: 4,
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
  final VoidCallback? onTap;

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
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  isActive ? Colors.white : Colors.white24,
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
      ),
    );
  }
}

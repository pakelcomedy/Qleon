import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CallView extends StatefulWidget {
  const CallView({super.key});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> with TickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = false;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _inCall = true;

  late final AnimationController _endBtnController;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _endBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _endBtnController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours.toString().padLeft(2, '0')}:$m:$s'
        : '$m:$s';
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() {
    if (_isVideoOn) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _toggleVideo() {
    HapticFeedback.selectionClick();
    setState(() {
      _isVideoOn = !_isVideoOn;
      if (_isVideoOn) _isSpeakerOn = true;
    });
  }

  Future<void> _endCall() async {
    HapticFeedback.heavyImpact();
    _timer?.cancel();

    await _endBtnController.reverse();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const callerName = 'Andi Wijaya';
    final callLabel = _formatDuration(_elapsed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _isVideoOn
                ? _buildVideoBackground()
                : _buildAudioBackground(callerName),
            Positioned(top: 8, left: 8, right: 8,
                child: _buildTopBar(callerName, callLabel)),
            Positioned(bottom: 28, left: 0, right: 0,
                child: _buildControls()),
            if (_isVideoOn)
              Positioned(top: 110, right: 14, child: _buildLocalPreview()),
          ],
        ),
      ),
    );
  }

  // ================= BACKGROUND =================

  Widget _buildVideoBackground() {
    return const Center(
      child: Text(
        'Remote video stream',
        style: TextStyle(color: Colors.white38),
      ),
    );
  }

  Widget _buildAudioBackground(String name) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.call, size: 72, color: Colors.white54),
          SizedBox(height: 20),
          Text(
            'Andi Wijaya',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text('Calling...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // ================= TOP BAR =================

  Widget _buildTopBar(String name, String time) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(_isVideoOn ? Icons.videocam : Icons.call,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(time,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  // ================= CONTROLS =================

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _controlBtn(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              active: _isMuted,
              onTap: _toggleMute,
            ),
            _speakerBtn(),
            _controlBtn(
              icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
              label: 'Video',
              active: _isVideoOn,
              onTap: _toggleVideo,
            ),
          ],
        ),
        const SizedBox(height: 28),
        ScaleTransition(
          scale: _endBtnController,
          child: GestureDetector(
            onTapDown: (_) => _endBtnController.reverse(),
            onTapUp: (_) async {
              await _endBtnController.forward();
              _endCall();
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.call_end,
                  color: Colors.white, size: 30),
            ),
          ),
        )
      ],
    );
  }

  Widget _speakerBtn() {
    final disabled = _isVideoOn;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: _controlBtn(
        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
        label: disabled ? 'Speaker (auto)' : 'Speaker',
        active: _isSpeakerOn,
        onTap: disabled ? null : _toggleSpeaker,
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 28,
            backgroundColor:
                active ? Colors.white : Colors.white24,
            child: Icon(icon,
                color: active ? Colors.black : Colors.white,
                size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildLocalPreview() {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(
        child: Text('You', style: TextStyle(color: Colors.white70)),
      ),
    );
  }
}

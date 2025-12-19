import 'package:flutter/material.dart';

class ArchiveView extends StatelessWidget {
  const ArchiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Archived Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'No archived chats',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

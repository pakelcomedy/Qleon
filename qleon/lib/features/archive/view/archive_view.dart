import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ArchiveView<T> extends StatefulWidget {
  final List<T> archivedChats;
  final void Function(T chat)? onUnarchive;

  const ArchiveView({
    super.key,
    required this.archivedChats,
    this.onUnarchive,
  });

  @override
  State<ArchiveView<T>> createState() => _ArchiveViewState<T>();
}

class _ArchiveViewState<T> extends State<ArchiveView<T>> {
  final Set<T> _selected = {};

  bool get _isSelection => _selected.isNotEmpty;

  void _toggleSelect(T chat) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected.contains(chat)
          ? _selected.remove(chat)
          : _selected.add(chat);
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  void _unarchiveSelected() {
    for (final chat in _selected) {
      widget.onUnarchive?.call(chat);
    }
    _clearSelection();
    Navigator.pop(context);
  }

  void _unarchiveSingle(T chat) {
    widget.onUnarchive?.call(chat);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _isSelection ? _selectionAppBar() : _normalAppBar(),
      body: widget.archivedChats.isEmpty
          ? _empty()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.archivedChats.length,
              itemBuilder: (_, i) {
                final chat = widget.archivedChats[i];
                final selected = _selected.contains(chat);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.blue.withOpacity(0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          _isSelection ? _toggleSelect(chat) : _unarchiveSingle(chat),
                      onLongPress: () {
                        if (!_isSelection) {
                          HapticFeedback.lightImpact();
                          _toggleSelect(chat);
                        }
                      },
                      child: ListTile(
                        leading: const Icon(
                          Icons.archive,
                          color: Color(0xFF4F46E5),
                        ),
                        title: Text((chat as dynamic).name),
                        subtitle: Text(
                          (chat as dynamic).lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  AppBar _normalAppBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Archived chats',
          style: TextStyle(color: Color(0xFF111827)),
        ),
      );

  AppBar _selectionAppBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('${_selected.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.unarchive, color: Color(0xFF4F46E5)),
            onPressed: _unarchiveSelected,
          ),
        ],
      );

  Widget _empty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No archived chats', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

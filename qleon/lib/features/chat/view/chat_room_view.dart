// qleon/lib/features/chat/view/chat_room_view.dart
// Updated to work with the new ChatRoomViewModel (media sending built-in).
// - No ChatMediaRoomViewModel required
// - Uses image_picker, file_picker, geolocator, url_launcher for picking/opening
// Add these dependencies in pubspec.yaml if not present:
//   image_picker, file_picker, geolocator, url_launcher, path

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import '../viewmodel/chat_room_viewmodel.dart';
import '../../call/view/call_view.dart';
import '../../group/view/group_detail_view.dart';
import 'contact_detail_view.dart';

class ChatRoomView extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool isGroup;

  const ChatRoomView({super.key, required this.conversationId, required this.title, this.isGroup = false});

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatRoomViewModel vm;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _replyToMessageId;
  int _lastMessagesLength = 0;
  String? _lastError;

  final Set<String> _locallyDeletedIds = {};

  bool get _selectionMode => vm.selectedMessageIds.isNotEmpty;
  bool get _canSend => _controller.text.trim().isNotEmpty && !vm.isSending && !_selectionMode;

  @override
  void initState() {
    super.initState();
    vm = ChatRoomViewModel(conversationId: widget.conversationId);

    vm.init().catchError((e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Init error: $e')));
    });

    vm.addListener(() {
      final err = vm.errorMessage;
      if (err != null && err != _lastError) {
        _lastError = err;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          });
        }
      }
    });

    _controller.addListener(_onTextChanged);
  }

  void _openContactOrGroupDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isGroup
            ? const GroupDetailView()
            : ContactDetailView(
                conversationIdOrId: widget.conversationId,
                title: widget.title,
              ),
      ),
    );
  }

  @override
  void dispose() {
    vm.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await vm.sendTextMessage(text, replyToMessageId: _replyToMessageId);
      if (!mounted) return;
      _controller.clear();
      _cancelReply();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(animated: true);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scroll_controller_has_clients_safe()) return;
    final pos = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(pos, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(pos);
    }
  }

  bool _scroll_controller_has_clients_safe() {
    try {
      return _scrollController.hasClients;
    } catch (_) {
      return false;
    }
  }

  void _startSelection(String messageId) {
    HapticFeedback.lightImpact();
    vm.startSelection(messageId);
  }

  void _toggleSelection(String messageId) {
    HapticFeedback.selectionClick();
    vm.toggleSelection(messageId);
  }

  void _clearSelection() => vm.clearSelection();

  void _setReply(String messageId) {
    setState(() => _replyToMessageId = messageId);
    vm.clearSelection();
  }

  void _cancelReply() => setState(() => _replyToMessageId = null);

  Future<void> _confirmDeleteSelection() async {
    final count = vm.selectedMessageIds.length;
    final ok = await _showConfirmSheet(
      title: count == 1 ? 'Delete message?' : 'Delete $count messages?',
      message: count == 1 ? 'Delete the selected message?' : 'Delete selected messages from this conversation?',
      destructive: true,
      primaryLabel: 'Delete',
    );
    if (ok == true) {
      final ids = vm.selectedMessageIds.toList();
      try {
        setState(() {
          _locallyDeletedIds.addAll(ids);
        });

        for (final id in ids) {
          try {
            await vm.delete(id);
          } catch (e) {
            debugPrint('[ChatRoomView] vm.delete failed for $id: $e');
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted locally')));
        _clearSelection();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _showClearChatDialog() async {
    final ok = await _showConfirmSheet(
      title: 'Clear chat?',
      message: 'All messages in this conversation will be removed locally (kept on server).',
      destructive: true,
      primaryLabel: 'Clear',
    );
    if (ok == true) {
      try {
        final ids = vm.messages.map((m) => m.id).toList();
        setState(() {
          _locallyDeletedIds.addAll(ids);
        });

        try {
          await vm.clear();
        } catch (e) {
          debugPrint('[ChatRoomView] vm.clear failed: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared locally')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear chat: $e')));
      }
    }
  }

  Future<bool?> _showConfirmSheet({required String title, required String message, bool destructive = false, String primaryLabel = 'Confirm'}) {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                )),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: destructive ? Colors.red : const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(primaryLabel, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCallAndNavigate() async {
    final ok = await _showConfirmSheet(
      title: 'Call ${widget.title}?',
      message: 'Start a voice call to this contact/group?',
      primaryLabel: 'Call',
    );
    if (ok == true) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CallView()));
    }
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF374151)),
          onPressed: _confirmCallAndNavigate,
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (action) {
            if (action == 0) {
              _openContactOrGroupDetail();
            } else if (action == 1) {
              _showClearChatDialog();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 0, child: Text(widget.isGroup ? 'Group info' : 'Contact info')),
            const PopupMenuItem(value: 1, child: Text('Clear chat', style: TextStyle(color: Colors.red))),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final single = vm.selectedMessageIds.length == 1;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: _clearSelection),
      title: Text(single ? '1 selected' : '${vm.selectedMessageIds.length} selected', style: const TextStyle(color: Color(0xFF111827))),
      actions: [
        if (single)
          IconButton(
            icon: const Icon(Icons.reply, color: Color(0xFF4F46E5)),
            onPressed: () {
              final id = vm.selectedMessageIds.first;
              _setReply(id);
            },
          ),
        IconButton(
          icon: const Icon(Icons.copy, color: Color(0xFF4F46E5)),
          onPressed: () async {
            final texts = vm.selectedMessageIds
                .where((id) => !(_locallyDeletedIds.contains(id)))
                .map((id) => vm.findMessageById(id)?.text ?? '')
                .where((t) => t.isNotEmpty)
                .join('\n');
            await Clipboard.setData(ClipboardData(text: texts));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            _clearSelection();
          },
        ),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteSelection),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatRoomViewModel>.value(
      value: vm,
      child: Consumer<ChatRoomViewModel>(builder: (context, model, _) {
        _locallyDeletedIds.removeWhere((id) => !model.messages.any((m) => m.id == id));
        final visibleMessages = model.messages.where((m) => !m.isDeleted && !_locallyDeletedIds.contains(m.id)).toList();

        if (visibleMessages.length != _lastMessagesLength) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom(animated: true);
          });
          _lastMessagesLength = visibleMessages.length;
        }

        final replyMessage = (_replyToMessageId != null) ? model.findMessageById(_replyToMessageId!) : null;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F3F6),
          appBar: _selectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
          body: Column(
            children: [
              Expanded(
                child: _MessagesListView(
                  key: const ValueKey('messages_list'),
                  messages: visibleMessages,
                  selectedIds: model.selectedMessageIds,
                  onLongPressSelect: (id) => _startSelection(id),
                  onTapSelect: (id) {
                    if (_selectionMode) _toggleSelection(id);
                  },
                  onSwipeReply: (msg) {
                    if (!_selectionMode) _setReply(msg.id);
                  },
                  scrollController: _scrollController,
                ),
              ),
              if (replyMessage != null && !_selectionMode)
                ReplyPreviewWidget(
                  key: ValueKey('reply_preview_${replyMessage.id}'),
                  message: replyMessage,
                  onCancel: _cancelReply,
                ),
              _buildInputBar(model),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInputBar(ChatRoomViewModel model) {
    final disabled = _selectionMode;
    final canSend = _canSend;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: disabled ? Colors.black12.withAlpha(15) : Colors.black12,
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.add, color: disabled ? Colors.grey.shade400 : const Color(0xFF4F46E5)),
              onPressed: disabled ? null : _openAttachmentSheet,
            ),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: disabled ? 0.5 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(22)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Scrollbar(
                      child: TextField(
                        controller: _controller,
                        enabled: !disabled,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(hintText: 'Type a message', border: InputBorder.none, isDense: true),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (canSend) _send();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: canSend ? 1 : 0.92,
              duration: const Duration(milliseconds: 180),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: canSend ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: canSend
                      ? () {
                          HapticFeedback.lightImpact();
                          _send();
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Attachment sheet: pick and then delegate to vm.sendImage/sendDocument/sendLocationMessage
  void _openAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              runSpacing: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AttachmentTile(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        await _pickImageFromGallery();
                      },
                    ),
                    _AttachmentTile(
                      icon: Icons.insert_drive_file,
                      label: 'Document',
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        await _pickDocument();
                      },
                    ),
                    _AttachmentTile(
                      icon: Icons.location_on,
                      label: 'Location',
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        await _pickLocationAndSend();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // simple hint
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Attach an image, document or your current location', style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (xfile == null) return;
      final file = File(xfile.path);
      final fileName = p.basename(xfile.path);
      final ext = p.extension(xfile.path).replaceFirst('.', '');
      final mime = (xfile.mimeType != null && xfile.mimeType!.isNotEmpty) ? xfile.mimeType : _mimeFromExtension(ext);
      await vm.sendImage(file, mimeType: mime, fileName: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image queued for upload')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) return;
      final file = File(path);
      final name = res.files.single.name;
      final ext = res.files.single.extension;
      final mime = _mimeFromExtension(ext);
      await vm.sendDocument(file, mimeType: mime, fileName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document queued for upload')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick document: $e')));
    }
  }

  Future<void> _pickLocationAndSend() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await vm.sendLocationMessage(pos.latitude, pos.longitude);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get/send location: $e')));
    }
  }

  // Map some common extensions to MIME types
  String? _mimeFromExtension(String? ext) {
    if (ext == null) return null;
    final e = ext.toLowerCase();
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      default:
        return null;
    }
  }
}

class _MessagesListView extends StatelessWidget {
  final List<ChatMessage> messages; // oldest -> newest
  final Set<String> selectedIds;
  final void Function(String id) onLongPressSelect;
  final void Function(String id) onTapSelect;
  final void Function(ChatMessage msg) onSwipeReply;
  final ScrollController scrollController;

  const _MessagesListView({
    Key? key,
    required this.messages,
    required this.selectedIds,
    required this.onLongPressSelect,
    required this.onTapSelect,
    required this.onSwipeReply,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isSelected = selectedIds.contains(msg.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MessageTileMV(
            key: ValueKey(msg.id),
            message: msg,
            allMessages: messages,
            selected: isSelected,
            onTap: () => onTapSelect(msg.id),
            onLongPress: () => onLongPressSelect(msg.id),
            onSwipeReply: () => onSwipeReply(msg),
          ),
        );
      },
    );
  }
}

class _MessageTileMV extends StatefulWidget {
  final ChatMessage message;
  final List<ChatMessage> allMessages;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  const _MessageTileMV({super.key, required this.message, required this.allMessages, required this.selected, required this.onTap, required this.onLongPress, required this.onSwipeReply});

  @override
  State<_MessageTileMV> createState() => _MessageTileMVState();
}

class _MessageTileMVState extends State<_MessageTileMV> with SingleTickerProviderStateMixin {
  double _dragX = 0.0;
  late final AnimationController _animController;
  static const double triggerDistance = 40.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX += d.delta.dx;
      if (_dragX < 0) _dragX = 0;
      if (_dragX > 100) _dragX = 100;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails e) {
    if (_dragX >= triggerDistance) {
      HapticFeedback.lightImpact();
      widget.onSwipeReply();
    }
    _resetDrag();
  }

  void _resetDrag() {
    _animController.reset();
    _animController.forward(from: 0);
    setState(() => _dragX = 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final isMe = widget.message.senderId == currentUid;
    final bgColor = isMe ? const Color(0xFF4F46E5) : Colors.white;
    final textColor = isMe ? Colors.white : const Color.fromARGB(255, 55, 116, 248);
    final time = _formatTimestamp(widget.message.createdAt);

    ChatMessage? replied;
    if (widget.message.replyToMessageId != null) {
      try {
        replied = widget.allMessages.firstWhere((m) => m.id == widget.message.replyToMessageId);
      } catch (_) {
        replied = null;
      }
    }

    Widget contentWidget;
    final type = widget.message.type;
    if (type == 'image') {
      contentWidget = _buildImagePreview(widget.message);
    } else if (type == 'file') {
      contentWidget = _buildFileTile(widget.message);
    } else if (type == 'location') {
      contentWidget = _buildLocationTile(widget.message);
    } else {
      // text or unknown
      contentWidget = Text(widget.message.text ?? '', style: TextStyle(color: textColor, fontStyle: FontStyle.normal));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragX * 0.5, 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.indigo.withAlpha((0.12 * 255).round()) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (replied != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          replied.text ?? (replied.type == 'image' ? '[Image]' : (replied.type == 'file' ? replied.fileName ?? '[File]' : '')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isMe ? Colors.white70 : Colors.black87, fontSize: 12),
                        ),
                      ),
                    contentWidget,
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: TextStyle(color: textColor.withAlpha((0.7 * 255).round()), fontSize: 10)),
                        if (widget.selected) const SizedBox(width: 8),
                        if (widget.selected) const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
                        if (widget.message.isLocal)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ChatMessage m) {
    final hasLocal = m.localPath != null && m.localPath!.isNotEmpty;
    final hasRemote = m.remoteUrl != null && m.remoteUrl!.isNotEmpty;

    final imageWidget = hasLocal
        ? Image.file(File(m.localPath!), fit: BoxFit.cover)
        : (hasRemote
            ? Image.network(m.remoteUrl!, fit: BoxFit.cover)
            : Container(
                height: 140,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image)),
              ));

    return GestureDetector(
      onTap: () {
        // open fullscreen if possible
        if (hasLocal || hasRemote) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImagePage(localPath: m.localPath, remoteUrl: m.remoteUrl)));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200, minHeight: 80),
          child: AspectRatio(aspectRatio: 16 / 9, child: imageWidget),
        ),
      ),
    );
  }

  Widget _buildFileTile(ChatMessage m) {
    final displayName = m.fileName ?? m.remoteUrl?.split('/').last ?? 'File';
    return GestureDetector(
      onTap: () async {
        // open remote url if present; otherwise attempt to open local file (best-effort)
        if (m.remoteUrl != null && m.remoteUrl!.isNotEmpty) {
          final uri = Uri.tryParse(m.remoteUrl!);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open file URL')));
          }
        } else if (m.localPath != null && m.localPath!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is available locally (open with file manager)')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No file URL available')));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 32, color: Color(0xFF4F46E5)),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(m.mimeType ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(ChatMessage m) {
    final lat = m.latitude;
    final lng = m.longitude;
    final label = m.text ?? (lat != null && lng != null ? 'Location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : 'Location');
    return GestureDetector(
      onTap: () async {
        if (lat == null || lng == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No coordinates')));
          return;
        }
        final googleMaps = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (await canLaunchUrl(googleMaps)) {
          await launchUrl(googleMaps, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open maps')));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class FullscreenImagePage extends StatelessWidget {
  final String? localPath;
  final String? remoteUrl;
  const FullscreenImagePage({super.key, this.localPath, this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (localPath != null && localPath!.isNotEmpty) {
      img = Image.file(File(localPath!), fit: BoxFit.contain);
    } else if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      img = Image.network(remoteUrl!, fit: BoxFit.contain);
    } else {
      img = const Center(child: Icon(Icons.broken_image, size: 64));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(child: InteractiveViewer(child: img)),
    );
  }
}

class ReplyPreviewWidget extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;

  const ReplyPreviewWidget({super.key, required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final label = message.senderId == (FirebaseAuth.instance.currentUser?.uid ?? '') ? 'You' : 'Contact';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                Text(message.text ?? (message.type == 'image' ? '[Image]' : (message.type == 'file' ? message.fileName ?? '[File]' : '')), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachmentTile({Key? key, required this.icon, required this.label, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            CircleAvatar(radius: 28, backgroundColor: const Color(0xFFEEF2FF), child: Icon(icon, color: const Color(0xFF4F46E5))),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// // chat_room_view.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../viewmodel/chat_room_viewmodel.dart';
// import '../../call/view/call_view.dart';
// import '../../group/view/group_detail_view.dart';
// import 'contact_detail_view.dart';

// /// ChatRoomView connected to ChatRoomViewModel (production-ready UI glue).
// /// Requires conversationId so VM can listen to messages.
// /// Optional: pass participantIds (list of UIDs) so VM knows recipients immediately.
// class ChatRoomView extends StatefulWidget {
//   final String conversationId;
//   final String title;
//   final bool isGroup;
//   final List<String>? participantIds;

//   const ChatRoomView({
//     super.key,
//     required this.conversationId,
//     required this.title,
//     this.isGroup = false,
//     this.participantIds,
//   });

//   @override
//   State<ChatRoomView> createState() => _ChatRoomViewState();
// }

// class _ChatRoomViewState extends State<ChatRoomView> {
//   late final ChatRoomViewModel vm;
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   String? _replyToMessageId;
//   int _lastMessagesLength = 0;
//   String? _lastError;

//   bool get _selectionMode => vm.selectedMessageIds.isNotEmpty;
//   bool get _canSend => _controller.text.trim().isNotEmpty && !vm.isSending && !_selectionMode;

//   @override
//   void initState() {
//     super.initState();

//     // construct VM (we may pass participantIds if available)
//     vm = ChatRoomViewModel(
//       conversationId: widget.conversationId,
//       participantIds: widget.participantIds,
//     );

//     // if caller supplied participant IDs, add them now
//     if (widget.participantIds != null && widget.participantIds!.isNotEmpty) {
//       vm.addParticipants(widget.participantIds!);
//     }

//     // try to infer participants from conversationId (useful when you used canonical id like uidA_uidB)
//     final inferred = _inferParticipantsFromConversationId(widget.conversationId);
//     if (inferred.isNotEmpty) vm.addParticipants(inferred);

//     // initialize VM (will also attempt to read conversation doc if needed)
//     vm.init().then((_) {
//       // mark read right after init
//       vm.markConversationRead();
//     }).catchError((e) {
//       if (kDebugMode) debugPrint('VM init error: $e');
//     });

//     // watch for vm errors to show snackbar once
//     vm.addListener(() {
//       final err = vm.errorMessage;
//       if (err != null && err != _lastError) {
//         _lastError = err;
//         if (mounted) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
//           });
//         }
//       }
//     });

//     _controller.addListener(_onTextChanged);
//     _scrollController.addListener(_onScroll);
//   }

//   @override
//   void dispose() {
//     try {
//       // best-effort: tell server we're not typing
//       vm.setTyping(false);
//     } catch (_) {}
//     vm.dispose();
//     _controller.removeListener(_onTextChanged);
//     _controller.dispose();
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _onTextChanged() {
//     vm.setTyping(_controller.text.trim().isNotEmpty);
//     setState(() {}); // update send button state
//   }

//   void _onScroll() {
//     if (_scrollController.hasClients &&
//         _scrollController.position.pixels <= 200 &&
//         vm.hasMore &&
//         !vm.isPaginating) {
//       vm.loadMore();
//     }
//   }

//   Future<void> _send() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;

//     try {
//       await vm.sendTextMessage(text, replyToMessageId: _replyToMessageId);
//       if (!mounted) return;
//       _controller.clear();
//       _cancelReply();
//       await Future.delayed(const Duration(milliseconds: 150));
//       if (!mounted) return;
//       if (_shouldAutoScroll()) _scrollToBottom(animated: true);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
//     }
//   }

//   bool _shouldAutoScroll() {
//     if (!_scrollController.hasClients) return true;
//     final max = _scrollController.position.maxScrollExtent;
//     final cur = _scrollController.position.pixels;
//     return (max - cur) <= 150;
//   }

//   void _scrollToBottom({bool animated = false}) {
//     if (!_scrollController.hasClients) return;
//     final pos = _scrollController.position.maxScrollExtent;
//     if (animated) {
//       _scrollController.animateTo(pos, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
//     } else {
//       _scrollController.jumpTo(pos);
//     }
//   }

//   void _startSelection(String messageId) {
//     HapticFeedback.lightImpact();
//     vm.startSelection(messageId);
//   }

//   void _toggleSelection(String messageId) {
//     HapticFeedback.selectionClick();
//     vm.toggleSelection(messageId);
//   }

//   void _clearSelection() {
//     vm.clearSelection();
//   }

//   void _setReply(String messageId) {
//     setState(() {
//       _replyToMessageId = messageId;
//     });
//     vm.clearSelection();
//   }

//   void _cancelReply() {
//     setState(() {
//       _replyToMessageId = null;
//     });
//   }

//   Future<void> _confirmDeleteSelection() async {
//     final count = vm.selectedMessageIds.length;
//     final ok = await _showConfirmSheet(
//       title: count == 1 ? 'Delete message?' : 'Delete $count messages?',
//       message: count == 1 ? 'Delete the selected message?' : 'Delete selected messages from this conversation?',
//       destructive: true,
//       primaryLabel: 'Delete',
//     );
//     if (ok == true) {
//       final ids = vm.selectedMessageIds.toList();
//       try {
//         await vm.deleteMessages(ids);
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
//       } catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
//       }
//     }
//   }

//   Future<bool?> _showConfirmSheet({
//     required String title,
//     required String message,
//     bool destructive = false,
//     String primaryLabel = 'Confirm',
//   }) {
//     return showModalBottomSheet<bool>(
//       context: context,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
//       backgroundColor: Colors.white,
//       builder: (ctx) {
//         return SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
//                 const SizedBox(height: 12),
//                 Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
//                 const SizedBox(height: 8),
//                 Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
//                 const SizedBox(height: 18),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: () => Navigator.of(ctx).pop(false),
//                         style: OutlinedButton.styleFrom(
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                           side: BorderSide(color: Colors.grey.shade300),
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                         ),
//                         child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () => Navigator.of(ctx).pop(true),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: destructive ? Colors.red : const Color(0xFF4F46E5),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                         ),
//                         child: Text(primaryLabel, style: const TextStyle(color: Colors.white)),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Future<void> _showClearChatDialog() async {
//     final ok = await _showConfirmSheet(
//       title: 'Clear chat?',
//       message: 'All messages in this conversation will be deleted locally.',
//       destructive: true,
//       primaryLabel: 'Clear',
//     );
//     if (ok == true) {
//       try {
//         final ids = vm.messages.map((m) => m.id).toList();
//         await vm.deleteMessages(ids);
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
//       } catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear chat: $e')));
//       }
//     }
//   }

//   Future<void> _confirmCallAndNavigate() async {
//     final ok = await _showConfirmSheet(
//       title: 'Call ${widget.title}?',
//       message: 'Start a voice call to this contact/group?',
//       primaryLabel: 'Call',
//     );
//     if (ok == true) {
//       if (!mounted) return;
//       Navigator.push(context, MaterialPageRoute(builder: (_) => const CallView()));
//     }
//   }

//   PreferredSizeWidget _buildNormalAppBar() {
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 0,
//       leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)), onPressed: () => Navigator.pop(context)),
//       title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
//       actions: [
//         IconButton(icon: const Icon(Icons.call_outlined, color: Color(0xFF374151)), onPressed: _confirmCallAndNavigate),
//         PopupMenuButton<_ChatMenuAction>(
//           icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
//           onSelected: (action) {
//             if (action == _ChatMenuAction.info) {
//               Navigator.push(context, MaterialPageRoute(builder: (_) => widget.isGroup ? const GroupDetailView() : const ContactDetailView()));
//             } else if (action == _ChatMenuAction.clear) {
//               _showClearChatDialog();
//             }
//           },
//           itemBuilder: (_) => [
//             PopupMenuItem(value: _ChatMenuAction.info, child: Text(widget.isGroup ? 'Group info' : 'Contact info')),
//             const PopupMenuItem(value: _ChatMenuAction.clear, child: Text('Clear chat', style: TextStyle(color: Colors.red))),
//           ],
//         ),
//       ],
//     );
//   }

//   PreferredSizeWidget _buildSelectionAppBar() {
//     final single = vm.selectedMessageIds.length == 1;
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 1,
//       leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: _clearSelection),
//       title: Text(single ? '1 selected' : '${vm.selectedMessageIds.length} selected', style: const TextStyle(color: Color(0xFF111827))),
//       actions: [
//         if (single)
//           IconButton(
//             icon: const Icon(Icons.reply, color: Color(0xFF4F46E5)),
//             onPressed: () {
//               final id = vm.selectedMessageIds.first;
//               _setReply(id);
//             },
//           ),
//         IconButton(
//           icon: const Icon(Icons.copy, color: Color(0xFF4F46E5)),
//           onPressed: () async {
//             final texts = vm.selectedMessageIds.map((id) => vm.findMessageById(id)?.text ?? '').join('\n');
//             await Clipboard.setData(ClipboardData(text: texts));
//             if (!mounted) return;
//             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
//             _clearSelection();
//           },
//         ),
//         IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteSelection),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider<ChatRoomViewModel>.value(
//       value: vm,
//       child: Consumer<ChatRoomViewModel>(builder: (context, model, _) {
//         if (model.messages.length != _lastMessagesLength) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (!mounted) return;
//             if (_shouldAutoScroll()) _scrollToBottom(animated: true);
//           });
//           _lastMessagesLength = model.messages.length;
//         }

//         final replyMessage = (_replyToMessageId != null) ? model.findMessageById(_replyToMessageId!) : null;

//         return Scaffold(
//           backgroundColor: const Color(0xFFF1F3F6),
//           appBar: _selectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
//           body: Column(
//             children: [
//               Expanded(
//                 child: model.isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : _MessagesListView(
//                         messages: model.messages,
//                         selectedIds: model.selectedMessageIds,
//                         onLongPressSelect: (id) => _startSelection(id),
//                         onTapSelect: (id) {
//                           if (_selectionMode) _toggleSelection(id);
//                         },
//                         onSwipeReply: (msg) {
//                           if (!_selectionMode) _setReply(msg.id);
//                         },
//                         scrollController: _scrollController,
//                         hasMore: model.hasMore,
//                       ),
//               ),
//               if (replyMessage != null && !_selectionMode)
//                 ReplyPreviewWidget(
//                   key: ValueKey('reply_preview_${replyMessage.id}'),
//                   message: replyMessage,
//                   onCancel: _cancelReply,
//                 ),
//               _buildInputBar(model),
//             ],
//           ),
//         );
//       }),
//     );
//   }

//   Widget _buildInputBar(ChatRoomViewModel model) {
//     final disabled = _selectionMode;
//     final canSend = _canSend;

//     return SafeArea(
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         curve: Curves.easeOut,
//         padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: disabled ? Colors.black12.withAlpha(15) : Colors.black12,
//               blurRadius: 8,
//             ),
//           ],
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             IconButton(
//               icon: Icon(Icons.add, color: disabled ? Colors.grey.shade400 : const Color(0xFF4F46E5)),
//               onPressed: disabled ? null : _openAttachmentSheet,
//             ),
//             Expanded(
//               child: AnimatedOpacity(
//                 duration: const Duration(milliseconds: 180),
//                 opacity: disabled ? 0.5 : 1,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//                   decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(22)),
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxHeight: 160),
//                     child: Scrollbar(
//                       child: TextField(
//                         controller: _controller,
//                         enabled: !disabled,
//                         keyboardType: TextInputType.multiline,
//                         minLines: 1,
//                         maxLines: 6,
//                         textInputAction: TextInputAction.newline,
//                         decoration: const InputDecoration(hintText: 'Type a message', border: InputBorder.none, isDense: true),
//                         onChanged: (_) => setState(() {}),
//                         onSubmitted: (_) {
//                           if (canSend) _send();
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             AnimatedScale(
//               scale: canSend ? 1 : 0.92,
//               duration: const Duration(milliseconds: 180),
//               child: CircleAvatar(
//                 radius: 22,
//                 backgroundColor: canSend ? const Color(0xFF4F46E5) : Colors.grey.shade400,
//                 child: IconButton(
//                   icon: const Icon(Icons.send, color: Colors.white, size: 20),
//                   onPressed: canSend
//                       ? () {
//                           HapticFeedback.lightImpact();
//                           _send();
//                         }
//                       : null,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _openAttachmentSheet() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
//       builder: (context) {
//         return SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Wrap(
//               runSpacing: 8,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     _AttachmentTile(
//                       icon: Icons.photo_library,
//                       label: 'Gallery',
//                       onTap: () async {
//                         Navigator.pop(context);
//                         if (!mounted) return;
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open gallery (placeholder)')));
//                       },
//                     ),
//                     _AttachmentTile(
//                       icon: Icons.insert_drive_file,
//                       label: 'Document',
//                       onTap: () async {
//                         Navigator.pop(context);
//                         if (!mounted) return;
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open documents (placeholder)')));
//                       },
//                     ),
//                     _AttachmentTile(
//                       icon: Icons.location_on,
//                       label: 'Location',
//                       onTap: () {
//                         Navigator.pop(context);
//                         if (!mounted) return;
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick location (placeholder)')));
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   /// Infer participant UIDs from conversationId when possible.
//   /// Heuristic: split on common separators and return tokens with length >= 10.
//   List<String> _inferParticipantsFromConversationId(String id) {
//     try {
//       final separators = RegExp(r'[_\-\:\|]');
//       final tokens = id.split(separators).map((t) => t.trim()).where((t) => t.length >= 10).toList();
//       return tokens;
//     } catch (_) {
//       return [];
//     }
//   }
// }

// /// Messages list widget (connected to VM data)
// class _MessagesListView extends StatelessWidget {
//   final List<ChatMessage> messages; // oldest -> newest
//   final Set<String> selectedIds;
//   final void Function(String id) onLongPressSelect;
//   final void Function(String id) onTapSelect;
//   final void Function(ChatMessage msg) onSwipeReply;
//   final ScrollController scrollController;
//   final bool hasMore;

//   const _MessagesListView({
//     super.key,
//     required this.messages,
//     required this.selectedIds,
//     required this.onLongPressSelect,
//     required this.onTapSelect,
//     required this.onSwipeReply,
//     required this.scrollController,
//     required this.hasMore,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ListView.builder(
//       controller: scrollController,
//       reverse: false,
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//       itemCount: messages.length + (hasMore ? 1 : 0),
//       itemBuilder: (context, index) {
//         if (index >= messages.length) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(vertical: 12),
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final msg = messages[index];
//         final isSelected = selectedIds.contains(msg.id);
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 10),
//           child: _MessageTileMV(
//             key: ValueKey(msg.id),
//             message: msg,
//             selected: isSelected,
//             onTap: () => onTapSelect(msg.id),
//             onLongPress: () => onLongPressSelect(msg.id),
//             onSwipeReply: () => onSwipeReply(msg),
//           ),
//         );
//       },
//     );
//   }
// }

// /// Message tile adapted to ChatMessage (VM)
// class _MessageTileMV extends StatefulWidget {
//   final ChatMessage message;
//   final bool selected;
//   final VoidCallback onTap;
//   final VoidCallback onLongPress;
//   final VoidCallback onSwipeReply;

//   const _MessageTileMV({
//     super.key,
//     required this.message,
//     required this.selected,
//     required this.onTap,
//     required this.onLongPress,
//     required this.onSwipeReply,
//   });

//   @override
//   State<_MessageTileMV> createState() => _MessageTileMVState();
// }

// class _MessageTileMVState extends State<_MessageTileMV> with SingleTickerProviderStateMixin {
//   double _dragX = 0.0;
//   late final AnimationController _animController;
//   static const double triggerDistance = 40.0;

//   @override
//   void initState() {
//     super.initState();
//     _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
//   }

//   @override
//   void dispose() {
//     _animController.dispose();
//     super.dispose();
//   }

//   void _onHorizontalDragUpdate(DragUpdateDetails d) {
//     setState(() {
//       _dragX += d.delta.dx;
//       if (_dragX < 0) _dragX = 0;
//       if (_dragX > 100) _dragX = 100;
//     });
//   }

//   void _onHorizontalDragEnd(DragEndDetails e) {
//     if (_dragX >= triggerDistance) {
//       HapticFeedback.lightImpact();
//       widget.onSwipeReply();
//     }
//     _resetDrag();
//   }

//   void _resetDrag() {
//     _animController.reset();
//     _animController.forward(from: 0);
//     setState(() => _dragX = 0);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final vm = Provider.of<ChatRoomViewModel>(context, listen: false);
//     final isMe = widget.message.senderId == vm.currentUid;
//     final bgColor = isMe ? const Color(0xFF4F46E5) : Colors.white;
//     final textColor = isMe ? Colors.white : const Color(0xFF111827);
//     final time = _formatTimestamp(widget.message.createdAt);

//     return GestureDetector(
//       behavior: HitTestBehavior.opaque,
//       onTap: widget.onTap,
//       onLongPress: widget.onLongPress,
//       onHorizontalDragUpdate: _onHorizontalDragUpdate,
//       onHorizontalDragEnd: _onHorizontalDragEnd,
//       child: Transform.translate(
//         offset: Offset(_dragX * 0.5, 0),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 160),
//           curve: Curves.easeInOut,
//           padding: const EdgeInsets.symmetric(vertical: 6),
//           decoration: BoxDecoration(
//             color: widget.selected ? Colors.indigo.withAlpha((0.12 * 255).round()) : Colors.transparent,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Align(
//             alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 320),
//               child: Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: bgColor,
//                   borderRadius: BorderRadius.only(
//                     topLeft: const Radius.circular(16),
//                     topRight: const Radius.circular(16),
//                     bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
//                     bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                   children: [
//                     if (widget.message.replyToMessageId != null)
//                       FutureBuilder<ChatMessage?>(
//                         future: Future.microtask(() => vm.findMessageById(widget.message.replyToMessageId!)),
//                         builder: (_, snap) {
//                           final replied = snap.data;
//                           if (replied == null) return const SizedBox.shrink();
//                           return Container(
//                             margin: const EdgeInsets.only(bottom: 6),
//                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                             decoration: BoxDecoration(
//                               color: isMe ? Colors.white10 : Colors.grey.shade100,
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               replied.text,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(color: isMe ? Colors.white70 : Colors.black87, fontSize: 12),
//                             ),
//                           );
//                         },
//                       ),
//                     Text(widget.message.text, style: TextStyle(color: textColor)),
//                     const SizedBox(height: 6),
//                     Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(time, style: TextStyle(color: textColor.withAlpha((0.7 * 255).round()), fontSize: 10)),
//                         if (widget.selected) const SizedBox(width: 8),
//                         if (widget.selected) const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
//                         if (widget.message.isLocal)
//                           const Padding(
//                             padding: EdgeInsets.only(left: 6),
//                             child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
//                           ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   static String _formatTimestamp(Timestamp ts) {
//     final dt = ts.toDate();
//     final now = DateTime.now();
//     if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
//       final hh = dt.hour.toString().padLeft(2, '0');
//       final mm = dt.minute.toString().padLeft(2, '0');
//       return '$hh:$mm';
//     }
//     return '${dt.day}/${dt.month}/${dt.year}';
//   }
// }

// /// Reply preview widget that shows the replied-to message summary
// class ReplyPreviewWidget extends StatelessWidget {
//   final ChatMessage message;
//   final VoidCallback onCancel;

//   const ReplyPreviewWidget({super.key, required this.message, required this.onCancel});

//   @override
//   Widget build(BuildContext context) {
//     final label = message.senderId == Provider.of<ChatRoomViewModel>(context, listen: false).currentUid ? 'You' : 'Contact';
//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       child: Row(
//         children: [
//           Container(width: 4, height: 40, color: const Color(0xFF4F46E5)),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
//                 const SizedBox(height: 6),
//                 Text(message.text, maxLines: 1, overflow: TextOverflow.ellipsis),
//               ],
//             ),
//           ),
//           IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
//         ],
//       ),
//     );
//   }
// }

// /// Attachment tile used in bottom sheet
// class _AttachmentTile extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//   const _AttachmentTile({super.key, required this.icon, required this.label, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: SizedBox(
//         width: 90,
//         child: Column(
//           children: [
//             CircleAvatar(radius: 28, backgroundColor: const Color(0xFFEEF2FF), child: Icon(icon, color: const Color(0xFF4F46E5))),
//             const SizedBox(height: 8),
//             Text(label, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Chat menu actions
// enum _ChatMenuAction { info, clear }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodel/archive_viewmodel.dart'; // adjust path if needed

/// Archive screen wired to ArchiveViewModel.
/// - Uses Provider (ChangeNotifier) to listen to VM.
/// - Pull to refresh, selection, unarchive (single / multi) and undo support.
class ArchiveView extends StatefulWidget {
  /// Optional externally-provided viewmodel (helpful for testing). If omitted,
  /// ArchiveView will create its own ArchiveViewModel.
  final ArchiveViewModel? viewModel;

  const ArchiveView({super.key, this.viewModel});

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  late final ArchiveViewModel _vm;
  ScaffoldMessengerState? _scaffold;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? ArchiveViewModel();
    // If the VM created here needs init beyond constructor, call it here.
  }

  @override
  void dispose() {
    // only dispose vm if we created it (i.e., widget.viewModel == null).
    if (widget.viewModel == null) {
      _vm.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // scaffold messenger reference for snackbars
    _scaffold = ScaffoldMessenger.of(context);

    return ChangeNotifierProvider<ArchiveViewModel>.value(
      value: _vm,
      child: Consumer<ArchiveViewModel>(
        builder: (context, vm, _) {
          final archived = vm.archivedChats;
          final isLoading = vm.isLoading;
          final error = vm.errorMessage;

          return Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            appBar: vm.selectionMode ? _selectionAppBar(vm) : _normalAppBar(vm),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: vm.refresh,
                child: Builder(builder: (ctx) {
                  if (isLoading && archived.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (error != null && archived.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton(
                            onPressed: vm.refresh,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    );
                  }

                  if (archived.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No archived chats', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: archived.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final chat = archived[i];
                      final selected = vm.selectedIds.contains(chat.id);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected ? Colors.blue.withOpacity(0.12) : Colors.white,
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
                          onTap: () {
                            if (vm.selectionMode) {
                              HapticFeedback.selectionClick();
                              vm.toggleSelection(chat.id);
                            } else {
                              // Default tap behaviour: open chat (you can adapt)
                              // Navigator.push(... to chat screen using chat.id)
                              // For now, toggle selection with long press and do nothing on single tap.
                            }
                          },
                          onLongPress: () {
                            if (!vm.selectionMode) HapticFeedback.lightImpact();
                            vm.toggleSelection(chat.id);
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEEF2FF),
                              child: Text(
                                _initials(chat.title),
                                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selected) const Icon(Icons.check_circle, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.unarchive, color: Color(0xFF4F46E5)),
                                  onPressed: () => _handleSingleUnarchive(vm, chat.id),
                                  tooltip: 'Unarchive',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            floatingActionButton: vm.selectionMode
                ? FloatingActionButton.extended(
                    onPressed: vm.unarchiveSelected,
                    label: const Text('Unarchive'),
                    icon: const Icon(Icons.unarchive),
                  )
                : null,
          );
        },
      ),
    );
  }

  AppBar _normalAppBar(ArchiveViewModel vm) => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Archived chats', style: TextStyle(color: Color(0xFF111827))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF374151)),
            onPressed: vm.refresh,
            tooltip: 'Refresh',
          ),
        ],
      );

  AppBar _selectionAppBar(ArchiveViewModel vm) => AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: vm.clearSelection),
        title: Text('${vm.selectedIds.length} selected', style: const TextStyle(color: Color(0xFF111827))),
        actions: [
          IconButton(
            icon: const Icon(Icons.unarchive, color: Color(0xFF4F46E5)),
            onPressed: () => _handleMultiUnarchive(vm),
            tooltip: 'Unarchive selected',
          ),
        ],
      );

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty ? '' : parts.first[0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _handleSingleUnarchive(ArchiveViewModel vm, String convId) {
    vm.unarchive(convId).then((_) {
      _showUndoSnackbar(vm);
    }).catchError((e) {
      _scaffold?.showSnackBar(SnackBar(content: Text('Failed to unarchive: $e')));
    });
  }

  void _handleMultiUnarchive(ArchiveViewModel vm) {
    final ids = vm.selectedIds.toList();
    vm.unarchiveMultiple(ids).then((_) {
      vm.clearSelection();
      _showUndoSnackbar(vm);
    }).catchError((e) {
      _scaffold?.showSnackBar(SnackBar(content: Text('Failed to unarchive: $e')));
    });
  }

  void _showUndoSnackbar(ArchiveViewModel vm) {
    _scaffold?.hideCurrentSnackBar();
    _scaffold?.showSnackBar(
      SnackBar(
        content: const Text('Unarchived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            vm.undoLastUnarchive().catchError((e) {
              _scaffold?.showSnackBar(SnackBar(content: Text('Undo failed: $e')));
            });
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

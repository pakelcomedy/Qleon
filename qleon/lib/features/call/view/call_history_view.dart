import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_view.dart';
import 'call_list_view.dart';

class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  late List<_DummyCall> _calls;
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _calls = List<_DummyCall>.from(dummyCalls);
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshed')),
    );
  }

  List<_DummyCall> get _filteredCalls {
    if (_query.isEmpty) return _calls;
    return _calls
        .where((c) =>
            c.displayName.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  void _clearAllHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text('All call history will be removed locally.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _calls.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call history cleared')),
      );
    }
  }

  Future<bool> _confirmDelete(_DummyCall call) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete call?'),
        content: Text('Delete call with ${call.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok == true;
  }

  void _showCallActions(_DummyCall call) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Voice call'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CallView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Contact info'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact info')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await _confirmDelete(call);
                if (ok) {
                  setState(() => _calls.remove(call));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calls = _filteredCalls;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _showSearch
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Search calls', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Calls',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () =>
                setState(() => _showSearch = !_showSearch),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearAllHistory();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'clear', child: Text('Clear call history')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: calls.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(40),
                children: const [
                  Icon(Icons.call, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No call history',
                      textAlign: TextAlign.center),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: calls.length,
                itemBuilder: (_, i) {
                  final call = calls[i];

                  return Dismissible(
                    key: ValueKey(call.publicId),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      final ok = await _confirmDelete(call);
                      if (ok) setState(() => _calls.remove(call));
                      return ok;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius:
                              BorderRadius.circular(18)),
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: GestureDetector(
                      onLongPress: () => _showCallActions(call),
                      child: _CallCard(
                        call: call,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CallView()),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add_call),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CallListView()));
        },
      ),
    );
  }
}

/// =============================================================
/// CALL CARD
/// =============================================================
class _CallCard extends StatelessWidget {
  final _DummyCall call;
  final VoidCallback onTap;

  const _CallCard({required this.call, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final missed = call.status == CallStatus.missed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          _CallIdentityIndicator(call: call),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(call.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: missed
                            ? Colors.redAccent
                            : const Color(0xFF111827))),
                const SizedBox(height: 6),
                Text(call.subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            children: [
              Text(call.time,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Icon(
                call.status == CallStatus.missed
                    ? Icons.call_missed
                    : Icons.call_made,
                size: 16,
                color: missed ? Colors.redAccent : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// IDENTITY
/// =============================================================
class _CallIdentityIndicator extends StatelessWidget {
  final _DummyCall call;
  const _CallIdentityIndicator({required this.call});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor:
          call.isGroup ? const Color(0xFFE5E7EB) : const Color(0xFFEEF2FF),
      child: Icon(
        call.isGroup ? Icons.groups_outlined : Icons.person_outline,
        color:
            call.isGroup ? Colors.grey : const Color(0xFF4F46E5),
      ),
    );
  }
}

/// =============================================================
/// MODELS
/// =============================================================
enum CallType { voice }
enum CallStatus { incoming, outgoing, missed }

class _DummyCall {
  final String publicId;
  final String displayName;
  final String subtitle;
  final String time;
  final CallType type;
  final CallStatus status;
  final bool isGroup;

  const _DummyCall({
    required this.publicId,
    required this.displayName,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.status,
    required this.isGroup,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyCalls = [
  _DummyCall(
    publicId: '0xA91F23D9',
    displayName: 'Andi Wijaya',
    subtitle: 'Outgoing • 3 min',
    time: '21:30',
    type: CallType.voice,
    status: CallStatus.outgoing,
    isGroup: false,
  ),
  _DummyCall(
    publicId: '0x77BC119A',
    displayName: 'Tim Qleon',
    subtitle: 'Missed call',
    time: '19:12',
    type: CallType.voice,
    status: CallStatus.missed,
    isGroup: true,
  ),
];

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color notificationGreen = Color(0xFF2E7D32);
const Color notificationBackground = Color(0xFFF5F7F5);

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.month}/${date.day}/${date.year} '
          '$hour:$minute $period';
    }
    return 'Just now';
  }

  Future<void> _markAsRead(
    BuildContext context,
    String notificationId,
    bool isRead,
  ) async {
    if (isRead) return;

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update notification: $e')),
        );
      }
    }
  }


  Future<void> _deleteNotification(
    BuildContext context,
    String notificationId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete notification: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will permanently delete all notifications in your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestore batches support up to 500 writes.
      for (var i = 0; i < docs.length; i += 450) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = docs.skip(i).take(450);
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in again.')),
      );
    }

    final notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: notificationBackground,
      appBar: AppBar(
        backgroundColor: notificationGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear all notifications',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              // The current list is obtained from Firestore when Clear All is tapped.
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;

              try {
                final query = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: currentUser.uid)
                    .get();

                if (!context.mounted) return;
                await _clearAllNotifications(context, query.docs);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to load notifications: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load notifications.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aDate = aTime is Timestamp
                ? aTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = bTime is Timestamp
                ? bTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 72,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Updates about your reports will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;
              final type = (data['type'] ?? '').toString();
              final title = (data['title'] ?? 'Notification').toString();
              final message = (data['message'] ?? '').toString();
              final reportTitle =
                  (data['reportTitle'] ?? '').toString();
              final date = _formatDate(data['createdAt']);

              final icon = type == 'new_report'
                  ? Icons.assignment_add
                  : type == 'report_deleted'
                      ? Icons.delete_forever_outlined
                      : Icons.update_rounded;

              return Card(
                elevation: isRead ? 1 : 3,
                color: isRead ? Colors.white : const Color(0xFFEAF4EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isRead
                        ? Colors.transparent
                        : notificationGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _markAsRead(context, doc.id, isRead),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              notificationGreen.withValues(alpha: 0.12),
                          child: Icon(icon, color: notificationGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: notificationGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(message),
                              if (reportTitle.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Report: $reportTitle',
                                  style: const TextStyle(
                                    color: notificationGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                date,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              if (!isRead) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to mark as read',
                                  style: TextStyle(
                                    color: notificationGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete notification',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              _deleteNotification(context, doc.id),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

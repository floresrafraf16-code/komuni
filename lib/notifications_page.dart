import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color notificationGreen = Color(0xFF39D98A);
const Color notificationBackground = Color(0xFF071A14);
const Color notificationSurface = Color(0xCC102B20);
const Color notificationBorder = Color(0x6639D98A);
const Color notificationMuted = Color(0xFFAAC5B6);
const Color notificationText = Color(0xFFE8FFF2);


void _showNotificationFeedback(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  final accent = isError ? const Color(0xFFFF737D) : notificationGreen;
  final background = isError
      ? const Color(0xFF3B2026)
      : const Color(0xFF103B2B);
  final icon = isError ? Icons.error_rounded : Icons.check_circle_rounded;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.65)),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFF0FFF5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
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
        _showNotificationFeedback(
          context,
          message: 'Unable to update notification. Please try again.',
          isError: true,
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
      if (context.mounted) {
        _showNotificationFeedback(
          context,
          message: 'Notification deleted.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showNotificationFeedback(
          context,
          message: 'Unable to delete notification. Please try again.',
          isError: true,
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
        backgroundColor: const Color(0xFF102B20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: notificationBorder),
        ),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(
            color: notificationText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete all notifications in your list.',
          style: TextStyle(color: notificationMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: notificationMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
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
      if (context.mounted) {
        _showNotificationFeedback(
          context,
          message: 'All notifications cleared.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showNotificationFeedback(
          context,
          message: 'Unable to clear notifications. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: notificationBackground,
        body: Center(
          child: Text(
            'Please log in again.',
            style: TextStyle(color: notificationText),
          ),
        ),
      );
    }

    final notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: notificationBackground,
      appBar: AppBar(
        backgroundColor: notificationBackground,
        foregroundColor: notificationText,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: notificationText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear all notifications',
            icon: const Icon(Icons.delete_sweep_outlined),
            color: notificationGreen,
            onPressed: () async {
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
                _showNotificationFeedback(
                  context,
                  message: 'Unable to load notifications. Please try again.',
                  isError: true,
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
                  style: const TextStyle(color: notificationMuted),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: notificationGreen),
            );
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

          final unreadCount = docs
              .where((doc) => doc.data()['isRead'] != true)
              .length;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: notificationSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: notificationBorder),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 68,
                        color: notificationGreen,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: notificationText,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Updates about your reports will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: notificationMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: notificationSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: notificationBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: notificationGreen,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Your updates',
                        style: TextStyle(
                          color: notificationText,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '$unreadCount unread',
                      style: const TextStyle(
                        color: notificationGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ...docs.map((doc) {
                final data = doc.data();
                final isRead = data['isRead'] == true;
                final type = (data['type'] ?? '').toString();
                final title = (data['title'] ?? 'Notification').toString();
                final message = (data['message'] ?? '').toString();
                final reportTitle = (data['reportTitle'] ?? '').toString();
                final date = _formatDate(data['createdAt']);

                final icon = type == 'new_report'
                    ? Icons.assignment_add
                    : type == 'report_deleted'
                        ? Icons.delete_forever_outlined
                        : Icons.update_rounded;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isRead
                        ? const Color(0xB310261D)
                        : const Color(0xE6173829),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isRead
                          ? Colors.white.withValues(alpha: 0.08)
                          : notificationGreen.withValues(alpha: 0.55),
                      width: isRead ? 1 : 1.2,
                    ),
                    boxShadow: [
                      if (!isRead)
                        BoxShadow(
                          color: notificationGreen.withValues(alpha: 0.08),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _markAsRead(context, doc.id, isRead),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: notificationGreen.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                          color: notificationText,
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
                                const SizedBox(height: 7),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: notificationMuted,
                                    height: 1.4,
                                  ),
                                ),
                                if (reportTitle.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    'Report: $reportTitle',
                                    style: const TextStyle(
                                      color: notificationGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: notificationMuted.withValues(
                                      alpha: 0.75,
                                    ),
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
                            onPressed: () =>
                                _deleteNotification(context, doc.id),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

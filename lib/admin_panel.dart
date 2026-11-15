import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color adminGreen = Color(0xFF39D98A);
const Color adminDarkGreen = Color(0xFFE8FFF2);
const Color adminBackground = Color(0xFF071A14);
const Color adminSurface = Color(0xCC102B20);
const Color adminBorder = Color(0x6639D98A);
const Color adminMuted = Color(0xFFAAC5B6);


enum AdminFeedbackType { success, error, warning, info }

void showAdminFeedback(
  BuildContext context, {
  required String message,
  AdminFeedbackType type = AdminFeedbackType.info,
}) {
  final Color background;
  final Color accent;
  final IconData icon;
  switch (type) {
    case AdminFeedbackType.success:
      background = const Color(0xFF103B2B);
      accent = const Color(0xFF39D98A);
      icon = Icons.check_circle_rounded;
      break;
    case AdminFeedbackType.error:
      background = const Color(0xFF3B2026);
      accent = const Color(0xFFFF737D);
      icon = Icons.error_rounded;
      break;
    case AdminFeedbackType.warning:
      background = const Color(0xFF3B301D);
      accent = const Color(0xFFFFC45C);
      icon = Icons.warning_rounded;
      break;
    case AdminFeedbackType.info:
      background = const Color(0xFF17313A);
      accent = const Color(0xFF72CFFF);
      icon = Icons.info_rounded;
      break;
  }
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

const List<String> reportStatuses = ['Pending', 'In Progress', 'Resolved'];
const List<String> reportCategories = [
  'Road',
  'Garbage',
  'Water',
  'Electricity',
  'Public Safety',
  'Drainage',
  'Streetlight',
  'Others',
];

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final TextEditingController _searchController = TextEditingController();
  String selectedFilter = 'All';
  String searchQuery = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get reportsStream =>
      FirebaseFirestore.instance.collection('reports').snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2118),
        foregroundColor: const Color(0xFFF2FFF7),
        elevation: 0,
        title: const Text(
          'KOMUNI Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reportsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load reports.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = [...?snapshot.data?.docs];
          reports.sort((a, b) {
            final aDate = a.data()['createdAt'];
            final bDate = b.data()['createdAt'];
            final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
            return bMillis.compareTo(aMillis);
          });

          int countFor(String status) =>
              reports.where((r) => r.data()['status'] == status).length;

          final query = searchQuery.trim().toLowerCase();
          final filteredReports = reports.where((report) {
            final data = report.data();
            final statusMatches = selectedFilter == 'All' ||
                (data['status'] ?? 'Pending') == selectedFilter;
            final searchable = [
              data['title'],
              data['category'],
              data['location'],
              data['userName'],
              data['userEmail'],
            ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
            return statusMatches && (query.isEmpty || searchable.contains(query));
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard Overview',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold,
                        color: adminDarkGreen)),
                const SizedBox(height: 6),
                const Text('Monitor and manage community reports.',
                    style: TextStyle(color: adminMuted)),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final cardWidth = (constraints.maxWidth - spacing) / 2;
                    return Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(width: cardWidth, child: _statCard('Total Reports', reports.length, Icons.assignment)),
                          SizedBox(width: cardWidth, child: _statCard('Pending', countFor('Pending'), Icons.pending_actions)),
                          SizedBox(width: cardWidth, child: _statCard('In Progress', countFor('In Progress'), Icons.autorenew)),
                          SizedBox(width: cardWidth, child: _statCard('Resolved', countFor('Resolved'), Icons.check_circle)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                const Text('All Reports',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold,
                        color: adminDarkGreen)),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search title, category, location, or user...',
                    hintStyle: const TextStyle(color: adminMuted),
                    prefixIcon: const Icon(Icons.search, color: adminGreen),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: adminSurface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: adminBorder)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by status',
                    labelStyle: const TextStyle(color: adminMuted),
                    filled: true,
                    fillColor: adminSurface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: adminBorder)),
                  ),
                  items: ['All', ...reportStatuses]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Color(0xFFE8FFF2)))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedFilter = value);
                  },
                ),
                const SizedBox(height: 10),
                Text('${filteredReports.length} report(s) found',
                    style: const TextStyle(color: adminMuted)),
                const SizedBox(height: 12),
                if (filteredReports.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('No reports match your search or filter.'),
                    ),
                  )
                else
                  ...filteredReports.map((report) {
                    final data = report.data();
                    final title = (data['title'] ?? 'Untitled Report').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    return Card(
                      color: adminSurface,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18), side: const BorderSide(color: adminBorder)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl,
                                    width: 52, height: 52, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _reportIcon()),
                              )
                            : _reportIcon(),
                        title: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0FFF5))),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((data['category'] ?? 'No category').toString(), style: const TextStyle(color: adminMuted)),
                              Text((data['location'] ?? 'No location').toString(), style: const TextStyle(color: adminMuted)),
                              const SizedBox(height: 6),
                              _statusChip((data['status'] ?? 'Pending').toString()),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: adminGreen),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AdminReportDetailsPage(reportId: report.id)),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reportIcon() => const CircleAvatar(
        backgroundColor: Color(0xFFE8F2E8),
        child: Icon(Icons.report_problem, color: adminGreen),
      );

  Widget _statCard(String title, int count, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: adminSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: adminBorder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, color: adminGreen, size: 28),
            const SizedBox(height: 12),
            Text('$count', style: const TextStyle(fontSize: 25,
                fontWeight: FontWeight.bold, color: adminDarkGreen)),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: adminMuted)),
          ]),
        ),
      ),
    );
  }
}

class AdminReportDetailsPage extends StatelessWidget {
  final String reportId;
  const AdminReportDetailsPage({super.key, required this.reportId});

  Future<void> _editReport(BuildContext context, Map<String, dynamic> data) async {
    final titleController = TextEditingController(text: (data['title'] ?? '').toString());
    final locationController = TextEditingController(text: (data['location'] ?? '').toString());
    final descriptionController = TextEditingController(text: (data['description'] ?? '').toString());
    String category = (data['category'] ?? 'Other').toString();
    if (!reportCategories.contains(category)) category = 'Others';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Report', style: TextStyle(color: Color(0xFFE8FFF2))),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleController,
                  decoration: const InputDecoration(labelText: 'Report title', labelStyle: TextStyle(color: adminMuted))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: adminMuted)),
                items: reportCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Color(0xFFE8FFF2))))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => category = value); },
              ),
              const SizedBox(height: 10),
              TextField(controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location', labelStyle: TextStyle(color: adminMuted))),
              const SizedBox(height: 10),
              TextField(controller: descriptionController, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: adminMuted))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF20B978)),
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    locationController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  showAdminFeedback(
                    context,
                    message: 'Please complete all fields.',
                    type: AdminFeedbackType.warning,
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': titleController.text.trim(),
                  'category': category,
                  'location': locationController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    if (result == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        ...result,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        showAdminFeedback(
          context,
          message: 'Report details updated successfully.',
          type: AdminFeedbackType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAdminFeedback(
          context,
          message: 'Unable to update the report. Please try again.',
          type: AdminFeedbackType.error,
        );
      }
    }
  }

  Future<void> _deleteReport(BuildContext context, Map<String, dynamic> data) async {
    final title = (data['title'] ?? 'this report').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Report?', style: TextStyle(color: Color(0xFFE8FFF2))),
        content: Text('Are you sure you want to permanently delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final ownerId = (data['userId'] ?? '').toString();
      final batch = firestore.batch();
      final reportRef = firestore.collection('reports').doc(reportId);
      if (ownerId.isNotEmpty) {
        final notificationRef = firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': ownerId,
          'type': 'report_deleted',
          'title': 'Report Deleted',
          'message': 'Your report "$title" was deleted by the administrator.',
          'reportId': reportId,
          'reportTitle': title,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      batch.delete(reportRef);
      await batch.commit();
      if (context.mounted) {
        showAdminFeedback(
          context,
          message: 'Report deleted successfully.',
          type: AdminFeedbackType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        showAdminFeedback(
          context,
          message: 'Unable to delete the report. Please try again.',
          type: AdminFeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2118),
        foregroundColor: const Color(0xFFF2FFF7),
        elevation: 0,
        title: const Text('Report Details'),
        actions: [
          IconButton(
            tooltip: 'Edit report',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final snap = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
              if (snap.exists && context.mounted) await _editReport(context, snap.data()!);
            },
          ),
          IconButton(
            tooltip: 'Delete report',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final snap = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
              if (snap.exists && context.mounted) await _deleteReport(context, snap.data()!);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').doc(reportId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load report.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Report not found.'));

          final data = snapshot.data!.data()!;
          final imageUrl = (data['imageUrl'] ?? '').toString();
          final createdAt = data['createdAt'];
          final currentStatus = (data['status'] ?? 'Pending').toString();
          final safeStatus = reportStatuses.contains(currentStatus) ? currentStatus : 'Pending';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(imageUrl, width: double.infinity, height: 230, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(height: 150, color: const Color(0xFF173D2C),
                      alignment: Alignment.center, child: const Text('Unable to load image'))),
                ),
              const SizedBox(height: 20),
              Text((data['title'] ?? 'Untitled Report').toString(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: adminDarkGreen)),
              const SizedBox(height: 12),
              _detailRow('Category', data['category']),
              _detailRow('Location', data['location']),
              _detailRow('Description', data['description']),
              _detailRow('Submitted by', data['userName']),
              _detailRow('Email', data['userEmail']),
              _detailRow('Report ID', reportId),
              _detailRow('Date submitted', createdAt is Timestamp
                  ? createdAt.toDate().toString().split('.')[0] : 'Not available'),
              const SizedBox(height: 20),
              const Text('Update Report Status', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: adminDarkGreen)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: safeStatus,
                decoration: InputDecoration(filled: true, fillColor: adminSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: reportStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Color(0xFFE8FFF2))))).toList(),
                onChanged: (newStatus) async {
                  if (newStatus == null || newStatus == safeStatus) return;
                  try {
                    final firestore = FirebaseFirestore.instance;
                    final batch = firestore.batch();
                    batch.update(firestore.collection('reports').doc(reportId), {
                      'status': newStatus,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    final ownerId = (data['userId'] ?? '').toString();
                    if (ownerId.isNotEmpty) {
                      final notificationRef = firestore.collection('notifications').doc();
                      batch.set(notificationRef, {
                        'userId': ownerId,
                        'type': 'status_update',
                        'title': 'Report Status Updated',
                        'message': 'Your report "${data['title'] ?? 'Community report'}" changed from $safeStatus to $newStatus.',
                        'reportId': reportId,
                        'reportTitle': (data['title'] ?? 'Community report').toString(),
                        'isRead': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    await batch.commit();
                    if (context.mounted) {
                      showAdminFeedback(
                        context,
                        message: 'Report status updated and owner notified.',
                        type: AdminFeedbackType.success,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showAdminFeedback(
                        context,
                        message: 'Unable to update the report status. Please try again.',
                        type: AdminFeedbackType.error,
                      );
                    }
                  }
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: adminGreen)),
      const SizedBox(height: 4),
      Text(value?.toString().isNotEmpty == true ? value.toString() : 'Not available',
          style: const TextStyle(fontSize: 15, color: Color(0xFFE0F2E8))),
    ]),
  );
}

Widget _statusChip(String status) {
  final color = status == 'Resolved'
      ? Colors.green
      : status == 'In Progress' ? Colors.orange : Colors.red;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
  );
}

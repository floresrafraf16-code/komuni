import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'admin_panel.dart';
import 'notifications_page.dart';
import 'firebase_options.dart';

// ------------------------------------------------------------
// APP CONFIGURATION
// ------------------------------------------------------------

const Color primaryGreen = Color(0xFF2E7D32);
const Color darkGreen = Color(0xFF1B5E20);
const Color charcoal = Color(0xFF263238);
const Color lightBackground = Color(0xFFF5F7F5);

// Cloudinary configuration.
// These values come from your Cloudinary account and upload preset.
const String cloudinaryCloudName = 'osxxyiet';
const String cloudinaryUploadPreset = 'komuni_reports';

// Firebase Authentication UID of the KOMUNI administrator.
const String komuniAdminUid = '9tm1DxhjvobuLvabTIMMFjcycWo2';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KOMUNI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        scaffoldBackgroundColor: lightBackground,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ------------------------------------------------------------
// AUTHENTICATION CHECK
// ------------------------------------------------------------

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

// ------------------------------------------------------------
// LOGIN AND REGISTER PAGE
// ------------------------------------------------------------

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isRegistering = false;
  bool isLoading = false;
  bool hidePassword = true;

  Future<void> authenticate() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        (isRegistering && nameController.text.trim().isEmpty)) {
      showMessage('Please complete all required fields.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isRegistering) {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed.');
    } catch (e) {
      showMessage('Something went wrong: $e');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 65,
                      color: primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'KOMUNI',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRegistering
                          ? 'Create your account'
                          : 'Welcome back!',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 28),
                    if (isRegistering) ...[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(isRegistering ? 'REGISTER' : 'LOGIN'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isRegistering = !isRegistering;
                        });
                      },
                      child: Text(
                        isRegistering
                            ? 'Already have an account? Login'
                            : "Don't have an account? Register",
                      ),
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
}

// ------------------------------------------------------------
// DASHBOARD
// ------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    final reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KOMUNI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs
                      .where((doc) => doc.data()['isRead'] != true)
                      .length ?? 0;

              return IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_rounded),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userStream,
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data();
          final name = userData?['name']?.toString() ?? 'User';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: reportsStream,
            builder: (context, reportsSnapshot) {
              int total = 0;
              int pending = 0;
              int inProgress = 0;
              int resolved = 0;

              if (reportsSnapshot.hasData) {
                final reports = reportsSnapshot.data!.docs;
                total = reports.length;

                for (final report in reports) {
                  final status = (report.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (status == 'pending') {
                    pending++;
                  } else if (status == 'in progress') {
                    inProgress++;
                  } else if (status == 'resolved') {
                    resolved++;
                  }
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryGreen, darkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.waving_hand_rounded,
                            color: Colors.white,
                            size: 35,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Together, let us build a better community.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Report Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: charcoal,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (reportsSnapshot.hasError)
                      const Text('Unable to load report statistics.')
                    else if (reportsSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth - 24) / 3;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                  title: 'Total',
                                  count: total,
                                  icon: Icons.assignment_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                  title: 'Pending',
                                  count: pending,
                                  icon: Icons.pending_actions_rounded,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                  title: 'In Progress',
                                  count: inProgress,
                                  icon: Icons.autorenew_rounded,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: StatCard(
                                  title: 'Resolved',
                                  count: resolved,
                                  icon: Icons.check_circle_rounded,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 30),
                    const Text(
                      'Quick Access',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: charcoal,
                      ),
                    ),
                    const SizedBox(height: 15),
                    FeatureCard(
                      icon: Icons.add_circle_rounded,
                      title: 'Create a Report',
                      description:
                          'Report maintenance issues in your community.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateReportPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FeatureCard(
                      icon: Icons.assignment_rounded,
                      title: 'My Reports',
                      description:
                          'View and monitor your submitted reports.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyReportsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('userId', isEqualTo: user.uid)
                          .snapshots(),
                      builder: (context, notificationSnapshot) {
                        final unreadCount = notificationSnapshot.data?.docs
                                .where((doc) => doc.data()['isRead'] != true)
                                .length ?? 0;

                        return FeatureCard(
                          icon: Icons.notifications_active_rounded,
                          title: 'Notifications',
                          description: unreadCount == 0
                              ? 'View updates about your community reports.'
                              : 'You have $unreadCount unread notification(s).',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FeatureCard(
                      icon: Icons.person_rounded,
                      title: 'Account Settings',
                      description: 'Manage your account information.',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSettingsPage(),
                          ),
                        );
                      },
                    ),
                    if (userData?['role']?.toString().toLowerCase() == 'admin') ...[
                      const SizedBox(height: 12),
                      FeatureCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Admin Panel',
                        description: 'Manage and monitor all community reports.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelPage(),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 25),
                    const Center(
                      child: Text(
                        'KOMUNI • Building Better Communities',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// CREATE REPORT PAGE
// ------------------------------------------------------------

class CreateReportPage extends StatefulWidget {
  const CreateReportPage({super.key});

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  final List<String> categories = [
    'Road',
    'Garbage',
    'Water',
    'Electricity',
    'Public Safety',
    'Drainage',
    'Streetlight',
    'Others',
  ];

  String selectedCategory = 'Road';
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  bool isSubmitting = false;

  Future<void> pickImage(ImageSource source) async {
    try {
      final image = await imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        selectedImageBytes = bytes;
      });
    } catch (e) {
      showMessage('Unable to select image: $e');
    }
  }

  Future<String> uploadImageToCloudinary(XFile image) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = cloudinaryUploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Cloudinary upload failed: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final imageUrl = responseData['secure_url']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return imageUrl;
  }

  Future<void> submitReport() async {
    if (!formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Please log in again before submitting a report.');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String? imageUrl;

      // Upload the photo first, if the user selected one.
      if (selectedImage != null) {
        imageUrl = await uploadImageToCloudinary(selectedImage!);
      }

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userName =
          userDocument.data()?['name']?.toString() ?? 'User';

      // Save the report first so Firestore Rules can verify it
      // before allowing the admin notification to be created.
      final firestore = FirebaseFirestore.instance;
      final reportRef = await firestore.collection('reports').add({
        'title': titleController.text.trim(),
        'category': selectedCategory,
        'description': descriptionController.text.trim(),
        'location': locationController.text.trim(),
        'imageUrl': imageUrl,
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email ?? '',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify the administrator about the newly submitted report.
      // If notification creation fails, keep the successfully saved report
      // and do not ask the user to submit it again.
      try {
        await firestore.collection('notifications').add({
          'userId': komuniAdminUid,
          'type': 'new_report',
          'title': 'New Community Report',
          'message': '$userName submitted a new report: '
              '${titleController.text.trim()}.',
          'reportId': reportRef.id,
          'reportTitle': titleController.text.trim(),
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (notificationError) {
        debugPrint(
          'Report saved, but admin notification failed: $notificationError',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your report was submitted successfully!'),
          backgroundColor: primaryGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      showMessage('Unable to submit report: $e');
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create a Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Report an Issue',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provide accurate information so your community '
                  'can respond to the issue.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Report Title',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Damaged road near the school',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a report title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe the issue.';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide at least 10 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: locationController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Purok 2, Barangay San Jose',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the issue location.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  'Photo Evidence',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Optional, but recommended. Add a photo to help '
                  'explain the issue.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (selectedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      selectedImageBytes!,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 42,
                          color: primaryGreen,
                        ),
                        SizedBox(height: 8),
                        Text('No photo selected'),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                if (selectedImage != null)
                  TextButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setState(() {
                              selectedImage = null;
                              selectedImageBytes = null;
                            });
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove Photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : submitReport,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      isSubmitting ? 'Submitting...' : 'Submit Report',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// MY REPORTS PAGE
// ------------------------------------------------------------

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    final reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your reports. Please try again.'),
            );
          }

          final reports = snapshot.data?.docs ?? [];

          reports.sort((a, b) {
            final aDate = a.data()['createdAt'] as Timestamp?;
            final bDate = b.data()['createdAt'] as Timestamp?;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return bDate.compareTo(aDate);
          });

          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Reports Yet',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your submitted community reports will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateReportPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create a Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final document = reports[index];
              final data = document.data();

              return ReportCard(
                reportId: document.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportCard({
    super.key,
    required this.reportId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Untitled Report';
    final category = data['category']?.toString() ?? 'Other';
    final location = data['location']?.toString() ?? 'No location';
    final status = data['status']?.toString() ?? 'Pending';
    final imageUrl = data['imageUrl']?.toString();

    return Card(
      color: Colors.white,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailsPage(
                reportId: reportId,
                data: data,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => reportPlaceholder(),
                      )
                    : reportPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StatusChip(status: status),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget reportPlaceholder() {
  return Container(
    width: 92,
    height: 92,
    color: Colors.grey.shade100,
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Colors.grey,
      size: 32,
    ),
  );
}

// ------------------------------------------------------------
// REPORT DETAILS PAGE
// ------------------------------------------------------------

class ReportDetailsPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportDetailsPage({
    super.key,
    required this.reportId,
    required this.data,
  });

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  static const List<String> categories = [
    'Road', 'Garbage', 'Water', 'Electricity', 'Public Safety',
    'Drainage', 'Streetlight', 'Others',
  ];

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }
    return 'Date unavailable';
  }

  Future<String> _uploadEditedImageToCloudinary(XFile image) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = cloudinaryUploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Image upload failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = decoded['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL.');
    }

    return secureUrl;
  }

  Future<void> editReport(Map<String, dynamic> data) async {
    final titleController =
        TextEditingController(text: (data['title'] ?? '').toString());
    final locationController =
        TextEditingController(text: (data['location'] ?? '').toString());
    final descriptionController =
        TextEditingController(text: (data['description'] ?? '').toString());

    String category = (data['category'] ?? 'Others').toString();
    if (!categories.contains(category)) category = 'Others';

    XFile? selectedEditImage;
    final currentImageUrl = (data['imageUrl'] ?? '').toString();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Edit My Report',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF263238),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () =>
                                  Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: selectedEditImage != null
                                ? FutureBuilder<Uint8List>(
                                    future: selectedEditImage!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        );
                                      }
                                      if (snapshot.hasError) {
                                        return const ColoredBox(
                                          color: Color(0xFFEEEEEE),
                                          child: Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                            ),
                                          ),
                                        );
                                      }
                                      return const ColoredBox(
                                        color: Color(0xFFEEEEEE),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  )
                                : currentImageUrl.isNotEmpty
                                    ? Image.network(
                                        currentImageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, _, _) =>
                                            const ColoredBox(
                                          color: Color(0xFFEEEEEE),
                                          child: Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const ColoredBox(
                                        color: Color(0xFFEEEEEE),
                                        child: Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            selectedEditImage == null
                                ? 'Change Report Image'
                                : 'Choose Another Image',
                          ),
                          onPressed: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 75,
                              maxWidth: 1600,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedEditImage = picked;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Report title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Changes'),
                                onPressed: () {
                                  if (titleController.text.trim().isEmpty ||
                                      locationController.text.trim().isEmpty ||
                                      descriptionController.text
                                          .trim()
                                          .isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please complete all fields.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(dialogContext, {
                                    'title': titleController.text.trim(),
                                    'category': category,
                                    'location': locationController.text.trim(),
                                    'description':
                                        descriptionController.text.trim(),
                                    '_selectedImage': selectedEditImage,
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();

    if (result == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || data['userId'] != user.uid) {
        throw Exception('You can only edit your own report.');
      }

      final selectedImage = result.remove('_selectedImage') as XFile?;
      if (selectedImage != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading new report image...')),
        );
        result['imageUrl'] =
            await _uploadEditedImageToCloudinary(selectedImage);
      }

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId)
          .update({
        ...result,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your report has been updated successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update report: $e')),
        );
      }
    }
  }

  Future<void> deleteReport(Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete My Report?'),
        content: Text('Are you sure you want to permanently delete "${data['title'] ?? 'this report'}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || data['userId'] != user.uid) throw Exception('You can only delete your own report.');
      await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your report has been deleted.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to delete report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reports').doc(widget.reportId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('Report Details')), body: const Center(child: Text('Unable to load report.')));
        if (snapshot.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(title: const Text('Report Details')), body: const Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || !snapshot.data!.exists) return Scaffold(appBar: AppBar(title: const Text('Report Details')), body: const Center(child: Text('This report is no longer available.')));

        final data = snapshot.data!.data()!;
        final isOwner = user != null && data['userId'] == user.uid;
        final imageUrl = data['imageUrl']?.toString();
        final title = data['title']?.toString() ?? 'Untitled Report';
        final description = data['description']?.toString() ?? '';
        final category = data['category']?.toString() ?? 'Other';
        final location = data['location']?.toString() ?? 'No location';
        final status = data['status']?.toString() ?? 'Pending';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Report Details'),
            actions: isOwner ? [
              IconButton(tooltip: 'Edit report', icon: const Icon(Icons.edit), onPressed: () => editReport(data)),
              IconButton(tooltip: 'Delete report', icon: const Icon(Icons.delete_outline), onPressed: () => deleteReport(data)),
            ] : null,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(imageUrl, height: 230, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(height: 180, color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined, size: 50))))
              else
                Container(height: 150, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey)),
              const SizedBox(height: 22),
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: charcoal)),
              const SizedBox(height: 12),
              StatusChip(status: status),
              const SizedBox(height: 22),
              detailSection('Category', category, Icons.category_outlined),
              detailSection('Location', location, Icons.location_on_outlined),
              detailSection('Date Submitted', formatDate(data['createdAt']), Icons.calendar_today_outlined),
              const SizedBox(height: 18),
              const Text('Description', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: charcoal)),
              const SizedBox(height: 8),
              Text(description.isEmpty ? 'No description provided.' : description, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
              const SizedBox(height: 20),
              Text('Report ID: ${widget.reportId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  Widget detailSection(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: primaryGreen), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: charcoal, fontWeight: FontWeight.w600, fontSize: 15)),
        ])),
      ]),
    );
  }
}

// ------------------------------------------------------------
// ACCOUNT SETTINGS PAGE
// ------------------------------------------------------------

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  Future<void> editFullName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Full Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'Enter your full name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Full name cannot be empty.')),
                );
                return;
              }
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'name': newName});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full name updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update name: $e')),
        );
      }
    }
  }

  Future<void> changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool hideCurrentPassword = true;
    bool hideNewPassword = true;
    bool hideConfirmPassword = true;
    bool isChangingPassword = false;
    bool passwordChangedSuccessfully = false;
    String? dialogError;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again before changing your password.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isChangingPassword,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'For your security, enter your current password '
                          'to verify your identity.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: hideCurrentPassword,
                          enabled: !isChangingPassword,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hideCurrentPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setDialogState(() {
                                  hideCurrentPassword = !hideCurrentPassword;
                                });
                              },
                              icon: Icon(
                                hideCurrentPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your current password.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: hideNewPassword,
                          enabled: !isChangingPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            helperText: 'Use at least 6 characters.',
                            suffixIcon: IconButton(
                              tooltip: hideNewPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setDialogState(() {
                                  hideNewPassword = !hideNewPassword;
                                });
                              },
                              icon: Icon(
                                hideNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a new password.';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            if (value == currentPasswordController.text) {
                              return 'New password must differ from current password.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: hideConfirmPassword,
                          enabled: !isChangingPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              tooltip: hideConfirmPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setDialogState(() {
                                  hideConfirmPassword = !hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                hideConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your new password.';
                            }
                            if (value != newPasswordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        if (passwordChangedSuccessfully) ...[
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Password changed successfully. Use your new password the next time you log in.',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChangingPassword
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(passwordChangedSuccessfully ? 'Done' : 'Cancel'),
                ),
                FilledButton.icon(
                  onPressed: (isChangingPassword || passwordChangedSuccessfully)
                      ? null
                      : () async {
                          FocusScope.of(dialogContext).unfocus();
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isChangingPassword = true;
                            dialogError = null;
                          });

                          try {
                            final credential =
                                EmailAuthProvider.credential(
                              email: user.email!,
                              password: currentPasswordController.text,
                            );

                            // Reauthenticate before changing a sensitive
                            // account credential.
                            await user.reauthenticateWithCredential(
                              credential,
                            );

                            await user.updatePassword(
                              newPasswordController.text,
                            );

                            // Keep the dialog mounted after the Firebase
                            // operation completes. The user closes it with
                            // Done, avoiding a route teardown during the
                            // asynchronous button callback.
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isChangingPassword = false;
                                passwordChangedSuccessfully = true;
                                dialogError = null;
                              });
                            }
                          } on FirebaseAuthException catch (e) {
                            String message;
                            switch (e.code) {
                              case 'wrong-password':
                              case 'invalid-credential':
                                message =
                                    'Your current password is incorrect.';
                                break;
                              case 'weak-password':
                                message =
                                    'The new password is too weak. '
                                    'Use at least 6 characters.';
                                break;
                              case 'requires-recent-login':
                                message =
                                    'Please log out and log in again, '
                                    'then retry changing your password.';
                                break;
                              case 'too-many-requests':
                                message =
                                    'Too many attempts. Please try again later.';
                                break;
                              case 'network-request-failed':
                                message =
                                    'Network error. Check your internet connection.';
                                break;
                              default:
                                message = e.message ??
                                    'Unable to change password. Please try again.';
                            }

                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isChangingPassword = false;
                                dialogError = message;
                              });
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isChangingPassword = false;
                                dialogError =
                                    'Something went wrong. Please try again.';
                              });
                            }
                            debugPrint('Change password error: $e');
                          }
                        },
                  icon: isChangingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.password),
                  label: Text(
                    isChangingPassword
                        ? 'Updating...'
                        : passwordChangedSuccessfully
                            ? 'Updated'
                            : 'Update Password',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // showDialog completes as soon as the route is popped, while the
    // reverse transition may still be using the TextEditingControllers.
    // Wait for the dialog transition to finish before disposing them.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data();
          final name = userData?['name']?.toString() ?? 'User';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.person,
                  size: 45,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Text(
                  user.email ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 30),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Full Name'),
                subtitle: Text(name),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editFullName(name),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email Address'),
                subtitle: Text(user.email ?? 'Not available'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: primaryGreen),
                title: const Text('Change Password'),
                subtitle: const Text(
                  'Update your password securely',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: changePassword,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}


// ------------------------------------------------------------
// STATUS CHIP
// ------------------------------------------------------------

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status.toLowerCase()) {
      case 'resolved':
        color = primaryGreen;
        break;
      case 'in progress':
        color = Colors.deepPurple;
        break;
      default:
        color = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// STATISTICS CARD
// ------------------------------------------------------------

class StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// QUICK ACCESS CARD
// ------------------------------------------------------------

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: primaryGreen.withValues(alpha: 0.12),
          child: Icon(icon, color: primaryGreen),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: charcoal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(description),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

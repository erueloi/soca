import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/services/data_recovery_service.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _showRecoveryDialog() async {
    final incorrectIdCtrl = TextEditingController(
      text: 'finca-1769028465203',
    ); // Known bad ID
    final correctIdCtrl = TextEditingController(text: 'mol-cal-jeroni');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reparar Dades Finca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Això canviarà la ID de la finca en totes les col·leccions. Fes-ho servir només si s\'ha corromput la ID.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: incorrectIdCtrl,
              decoration: const InputDecoration(labelText: 'ID Incorrecte'),
            ),
            TextField(
              controller: correctIdCtrl,
              decoration: const InputDecoration(
                labelText: 'ID Correcte (Original)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('REPARAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = ref.read(authRepositoryProvider).currentUser;
        if (user == null) throw Exception('No Authorized User Found');

        final service = DataRecoveryService(FirebaseFirestore.instance);
        final results = await service.revertFincaId(
          incorrectIdCtrl.text.trim(),
          correctIdCtrl.text.trim(),
          user.uid,
        );

        if (mounted) {
          String summary = results.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n');
          showDialog(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: const Text('Resultat Reparació'),
              content: Text('Documents actualitzats:\n$summary'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Load initial data
    final user = ref.read(authRepositoryProvider).currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateDisplayName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canvis guardats correctament')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tancar Sessió'),
        content: const Text('Segur que vols sortir de l\'aplicació?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sortir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        await ref.read(authRepositoryProvider).signOut();
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Widget _buildDevicesSection(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.devices, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Dispositius Connectats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final Map<dynamic, dynamic> tokensMap =
                data?['fcmTokens'] as Map<dynamic, dynamic>? ?? {};

            // Sort by lastSeen descending
            final sortedKeys = tokensMap.keys.toList()
              ..sort((a, b) {
                final dateA = (tokensMap[a]['lastSeen'] as Timestamp?)
                    ?.toDate();
                final dateB = (tokensMap[b]['lastSeen'] as Timestamp?)
                    ?.toDate();
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });

            if (sortedKeys.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Cap dispositiu configurat per rebre notificacions.',
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final deviceId = sortedKeys[index];
                final info = tokensMap[deviceId] as Map<dynamic, dynamic>;

                final name = info['name'] ?? 'Dispositiu desconegut';
                final platform = info['platform'] ?? 'unknown';
                final lastSeenTs = info['lastSeen'] as Timestamp?;
                final lastSeen = lastSeenTs != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(lastSeenTs.toDate())
                    : '-';

                IconData platformIcon = Icons.smartphone;
                if (platform == 'ios') platformIcon = Icons.phone_iphone;
                if (platform == 'android') platformIcon = Icons.phone_android;
                if (platform == 'web') platformIcon = Icons.web;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(platformIcon, color: Colors.grey.shade700),
                    ),
                    title: Text(name.toString()),
                    subtitle: Text('Ultima connexió: $lastSeen'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteDevice(userId, deviceId),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _deleteDevice(String userId, String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dispositiu?'),
        content: const Text(
          'Aquest dispositiu deixarà de rebre notificacions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'fcmTokens.$deviceId': FieldValue.delete()},
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dispositiu eliminat.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;

    // We can also fetch the user Document from Firestore if we want to show 'authorizedFincas'
    // For now, simple Profile info.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil d\'Usuari'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveChanges,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('No hi ha cap usuari autenticat'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      onForegroundImageError: (exception, stackTrace) {
                        // Safely ignored, falls back to child
                      },
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.email ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de visualització',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nom no pot estar buit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    _buildDevicesSection(user.uid),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('TANCAR SESSIÓ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return Text(
                          'Versió de l\'app: ${snapshot.data!.version} (Build ${snapshot.data!.buildNumber})',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _showRecoveryDialog,
                      icon: const Icon(
                        Icons.build_circle,
                        color: Colors.orange,
                      ),
                      label: const Text('REPARAR DADES (FincaID incorrecte)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

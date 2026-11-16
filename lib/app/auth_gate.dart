import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dev_mobile/app/shells.dart';
import 'package:dev_mobile/features/utilisateurs/screens/login_screen.dart';

/// Détermine l'écran à afficher selon l'état d'authentification et le rôle.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return LoginScreen(
            onLoggedIn: () {}, // La reconstruction se fait via le StreamBuilder
          );
        }

        // Utilisateur connecté : vérifier son rôle dans Firestore
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userDoc = userSnapshot.data;
            if (userDoc == null || !userDoc.exists) {
              // Utilisateur sans document Firestore → traiter comme client
              return const ClientShell();
            }

            final userData = userDoc.data() as Map<String, dynamic>;
            final role = userData['role'] as String? ?? 'client';

            return role == 'admin' ? const AdminShell() : const ClientShell();
          },
        );
      },
    );
  }
}
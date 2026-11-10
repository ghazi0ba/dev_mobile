import 'package:flutter/material.dart';

/// Palette CosmaPlus, tirée des maquettes.
/// N'utilisez jamais de couleur en dur dans les écrans : passez par AppColors.
class AppColors {
  AppColors._();

  // Marque
  static const primary = Color(0xFF8A4832); // terracotta (boutons, éléments actifs)
  static const primaryDark = Color(0xFF6E3726);
  static const accent = Color(0xFFE8A68A); // pêche (étiquettes sur image)

  // Fonds
  static const background = Color(0xFFF7F7FC); // fond des écrans
  static const surface = Color(0xFFFFFFFF); // cartes
  static const surfaceMuted = Color(0xFFF0F1FA); // champs de saisie, blocs info
  static const secondary = Color(0xFFEADED8); // boutons secondaires, chips
  static const border = Color(0xFFE4E4EC);

  // Texte
  static const textPrimary = Color(0xFF1E1E24);
  static const textSecondary = Color(0xFF5F606B);
  static const textHint = Color(0xFF9CA2AE);

  // Statuts
  static const success = Color(0xFF3E7D55);
  static const successLight = Color(0xFFD4EBD9);
  static const warning = Color(0xFFB7791F);
  static const warningLight = Color(0xFFF8EBD3);
  static const error = Color(0xFFB3261E);
  static const errorLight = Color(0xFFFCE4E1);
  static const neutralLight = Color(0xFFECECF4);
}

import 'package:flutter/material.dart';

import '../logic/player_progress.dart';

/// Colors for one cosmetic theme. Liquid colors stay the same in every theme
/// so puzzles read the same; only the room, glass, rack and panels change.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.skyTop,
    required this.skyBottom,
    required this.panel,
    required this.panelBorder,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.accentInk,
    required this.button,
    required this.buttonInk,
    required this.glass,
    required this.glassEdge,
    required this.rackTop,
    required this.rackBottom,
    required this.star,
    required this.danger,
    required this.dark,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color panel;
  final Color panelBorder;
  final Color text;
  final Color textSecondary;
  final Color accent;

  /// Text drawn on [accent].
  final Color accentInk;
  final Color button;
  final Color buttonInk;
  final Color glass;
  final Color glassEdge;
  final Color rackTop;
  final Color rackBottom;
  final Color star;
  final Color danger;

  /// True for dark rooms (light text on panels).
  final bool dark;

  static ThemePalette of(PourTheme theme) => switch (theme) {
    PourTheme.lab => lab,
    PourTheme.potionShop => potionShop,
    PourTheme.candy => candy,
    PourTheme.nightBar => nightBar,
  };

  static const lab = ThemePalette(
    skyTop: Color(0xFF1B4E6B),
    skyBottom: Color(0xFF0E2A3F),
    panel: Color(0xE6F4FBFF),
    panelBorder: Color(0xFFBFE3F2),
    text: Color(0xFF12324A),
    textSecondary: Color(0xFF4F7489),
    accent: Color(0xFF22C3B5),
    accentInk: Color(0xFF053B37),
    button: Color(0xFFFFFFFF),
    buttonInk: Color(0xFF1B4E6B),
    glass: Color(0xFFD9F3FF),
    glassEdge: Color(0xFFEAF8FF),
    rackTop: Color(0xFFB7C7D3),
    rackBottom: Color(0xFF6E8596),
    star: Color(0xFFFFC83D),
    danger: Color(0xFFFF6B6B),
    dark: false,
  );

  static const potionShop = ThemePalette(
    skyTop: Color(0xFF4A2B4F),
    skyBottom: Color(0xFF26142B),
    panel: Color(0xEB3A2233),
    panelBorder: Color(0xFF8C5A3C),
    text: Color(0xFFFFEBD2),
    textSecondary: Color(0xFFD9B391),
    accent: Color(0xFFF2A541),
    accentInk: Color(0xFF3B1F05),
    button: Color(0xFF5A3448),
    buttonInk: Color(0xFFFFE3BF),
    glass: Color(0xFFFFE9D2),
    glassEdge: Color(0xFFFFF3E3),
    rackTop: Color(0xFFA0683F),
    rackBottom: Color(0xFF5C3520),
    star: Color(0xFFFFCF4A),
    danger: Color(0xFFFF7A6B),
    dark: true,
  );

  static const candy = ThemePalette(
    skyTop: Color(0xFFFFC7DE),
    skyBottom: Color(0xFFB9F0E4),
    panel: Color(0xEFFFFFFF),
    panelBorder: Color(0xFFFFB3D1),
    text: Color(0xFF6B2A55),
    textSecondary: Color(0xFFA0628A),
    accent: Color(0xFFFF6FAE),
    accentInk: Color(0xFFFFFFFF),
    button: Color(0xFFFFFFFF),
    buttonInk: Color(0xFFD94A8C),
    glass: Color(0xFFFFFFFF),
    glassEdge: Color(0xFFFFFFFF),
    rackTop: Color(0xFFFF9EC7),
    rackBottom: Color(0xFFE0609A),
    star: Color(0xFFFFB627),
    danger: Color(0xFFE5484D),
    dark: false,
  );

  static const nightBar = ThemePalette(
    skyTop: Color(0xFF1A1440),
    skyBottom: Color(0xFF07061A),
    panel: Color(0xE6161233),
    panelBorder: Color(0xFF5B3FD1),
    text: Color(0xFFF1EBFF),
    textSecondary: Color(0xFFA99BDB),
    accent: Color(0xFF2EE6D6),
    accentInk: Color(0xFF03302C),
    button: Color(0xFF241D52),
    buttonInk: Color(0xFFD7CCFF),
    glass: Color(0xFFCFC4FF),
    glassEdge: Color(0xFFE6DEFF),
    rackTop: Color(0xFF3A2F7A),
    rackBottom: Color(0xFF17123A),
    star: Color(0xFFFFD84D),
    danger: Color(0xFFFF5C8A),
    dark: true,
  );
}

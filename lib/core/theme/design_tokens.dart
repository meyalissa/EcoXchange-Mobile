import 'package:flutter/material.dart';

/// EcoXchange Mobile — design tokens transcribed directly from the
/// approved HTML/CSS design's `assets/css/app.css` (`:root` custom
/// properties). Every value here has a named counterpart there (e.g.
/// [green500] ↔ `--g500`) — kept as a single source so colours/radii/
/// shadows/spacing are never hardcoded differently per screen (Phase
/// 4C.3 §3/§4).
class AppColors {
  AppColors._();

  // Green scale (--g50…--g900)
  static const green50 = Color(0xFFF2F5EC);
  static const green100 = Color(0xFFDDEACE);
  static const green200 = Color(0xFFC0D4A4);
  static const green300 = Color(0xFFA3BE7B);
  static const green400 = Color(0xFF8BAD65);
  static const green500 = Color(0xFF849B60);
  static const green600 = Color(0xFF6A8D53);
  static const green700 = Color(0xFF527040);
  static const green800 = Color(0xFF3A522D);
  static const green900 = Color(0xFF1F2D18);

  // Accents
  static const gold = Color(0xFFE8A020);
  static const goldLight = Color(0xFFFDF3DC);
  static const teal = Color(0xFF0AADA8);
  static const tealLight = Color(0xFFE0F7F6);
  static const red = Color(0xFFE53E3E);
  static const redLight = Color(0xFFFEE2E2);
  static const blue = Color(0xFF2563EB);
  static const blueLight = Color(0xFFDBEAFE);

  // Neutral scale (--n0…--n900)
  static const n0 = Color(0xFFFFFFFF);
  static const n50 = Color(0xFFF8FAF5);
  static const n100 = Color(0xFFEFF3EA);
  static const n200 = Color(0xFFDDE6D5);
  static const n300 = Color(0xFFC4D4B8);
  static const n400 = Color(0xFF9BB58A);
  static const n500 = Color(0xFF738F63);
  static const n600 = Color(0xFF587048);
  static const n700 = Color(0xFF405233);
  static const n800 = Color(0xFF2A361F);
  static const n900 = Color(0xFF141A0E);

  // Hero/gradient combinations lifted verbatim from specific screens.
  static const loginHeroGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF2D4422), Color(0xFF527040)],
  );
  static const homeHeroGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF2D4422), Color(0xFF527040), green500],
    stops: [0, 0.55, 1],
  );
  static const walletCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green700, green500, green300],
    stops: [0, 0.55, 1],
  );
  static const pickupHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green600, green400],
  );
  static const rewardsHeroGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF7B4F00), Color(0xFFC87A00)],
  );
  static const fabGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green500, green700],
  );
}

/// Border radii (--r4…--r24, --r-full).
class AppRadii {
  AppRadii._();
  static const r4 = 4.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const r24 = 24.0;
  static const rFull = 999.0;
}

/// Layered shadows (--sh1…--sh3 — sh4 is unused by any in-scope screen).
class AppShadows {
  AppShadows._();

  static const sh1 = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sh2 = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const sh3 = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
}

/// Spacing scale used throughout app.css's utility classes (gap-4…gap-16,
/// mt-4…mt-20, p-16). Not exhaustive — just the values actually reused.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

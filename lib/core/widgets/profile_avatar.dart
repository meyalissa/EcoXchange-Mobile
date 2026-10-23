import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// EcoXchange Mobile — the one circular profile-photo/initials avatar,
/// shared by Home (`dashboard_screen.dart`) and Profile
/// (`customer_profile_screen.dart`).
///
/// Root cause this fixes: Home never had this widget at all — its own
/// `_Avatar` only ever rendered the name's initial, with no `photoUrl`
/// parameter to even look at, while Profile's (otherwise identical)
/// `_ProfileAvatar` already did the real thing. `AuthProvider.user` was
/// already the single, already-synchronized data source in both places
/// (`EditPersonalInfoProvider` pushes every save — photo or otherwise —
/// into it via `applyUpdatedUser()`), so there was no caching/staleness
/// bug to fix, no second data source to reconcile and no extra refresh
/// logic needed: Home just never read the field that was already there.
/// Extracting this one real implementation (instead of leaving two
/// separately-maintained copies) is what makes "same authoritative data"
/// guaranteed rather than merely coincidental.
///
/// [photoUrl] is the server's own `profile_photo_url` — null shows
/// [initials] directly; a non-null URL that fails to load (a genuine
/// network/decode failure) falls back to [initials] too, via
/// [AppNetworkImage]'s `errorBuilder` — never a blank circle, never a
/// broken-image icon in its place.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.photoUrl,
    this.size = 52,
    this.borderWidth = 2.5,
  });

  final String initials;
  final String? photoUrl;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final fallback = Text(
      initials,
      style: AppTheme.displayFont(fontSize: size * 0.37, fontWeight: FontWeight.w900, color: Colors.white),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: borderWidth),
      ),
      child: url != null
          ? AppNetworkImage(
              url: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => fallback,
            )
          : fallback,
    );
  }
}

/// `name.isNotEmpty ? name[0].toUpperCase() : '?'` — the one initials rule
/// both Home and Profile already used identically; kept here so neither
/// call site has to repeat it.
String initialOf(String name) => name.isNotEmpty ? name[0].toUpperCase() : '?';

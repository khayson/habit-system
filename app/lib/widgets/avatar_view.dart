import 'dart:io';

import 'package:flutter/material.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';

/// The design's avatar sizes (A20): 24, 40 and 80.
enum AvatarSize {
  small(24),
  medium(40),
  large(80);

  const AvatarSize(this.dimension);
  final double dimension;
}

/// A20: the profile photo, or initials when there is none (or the file cannot be read). Read
/// as "Profile photo of {name}". When tappable the target is at least 44 px.
class AvatarView extends StatelessWidget {
  final String? photoPath;
  final String initials;
  final String name;
  final AvatarSize size;
  final VoidCallback? onTap;
  final String? tapHint;

  const AvatarView({
    super.key,
    required this.photoPath,
    required this.initials,
    required this.name,
    this.size = AvatarSize.medium,
    this.onTap,
    this.tapHint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    final text = Theme.of(context).textTheme;
    final d = size.dimension;
    Widget fallback() => Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tokens.positiveBg, shape: BoxShape.circle),
      child: Text(
        initials,
        textScaler: TextScaler.noScaling,
        style: (size == AvatarSize.large ? text.headlineSmall : text.labelLarge)?.copyWith(
          color: tokens.positiveInk,
          fontSize: d * 0.4,
        ),
      ),
    );
    final path = photoPath;
    final picture = path == null
        ? fallback()
        : ClipOval(
            child: Image.file(
              File(path),
              width: d,
              height: d,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
          );
    final target = d < HabitSize.minTarget && onTap != null ? HabitSize.minTarget : d;
    // Its own node, so the label is never merged with the name beside it.
    return Semantics(
      container: true,
      image: true,
      button: onTap != null,
      label: AppLocalizations.of(context).avatarLabel(name),
      hint: tapHint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: target,
          child: Center(child: picture),
        ),
      ),
    );
  }
}

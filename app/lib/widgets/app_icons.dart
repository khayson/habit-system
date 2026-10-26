import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../domain/habit_icons.dart';
import 'habit_icon_glyphs.g.dart';

/// A52: one icon as Hugeicons draws it (stroke-rounded SVG paths).
typedef AppIconData = List<List<dynamic>>;

/// A52: every icon the app draws, named by meaning, from the free Hugeicons stroke-rounded set
/// (MIT). The only file that names a Hugeicons glyph; an architecture test keeps it that way.
abstract final class AppIcons {
  // Navigation (the bottom bar and headers).
  static const AppIconData today = HugeIcons.strokeRoundedHome01;
  static const AppIconData habits = HugeIcons.strokeRoundedCalendar01;
  static const AppIconData insights = HugeIcons.strokeRoundedChartColumn;
  static const AppIconData profile = HugeIcons.strokeRoundedUser;
  static const AppIconData back = HugeIcons.strokeRoundedArrowLeft01;
  static const AppIconData chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const AppIconData expand = HugeIcons.strokeRoundedArrowDown01;
  static const AppIconData close = HugeIcons.strokeRoundedCancel01;

  // Habit types (design sheet: a check, a drop, a clock) and their fallback.
  static const AppIconData yesNo = HugeIcons.strokeRoundedTick02;
  static const AppIconData quantity = HugeIcons.strokeRoundedDroplet;
  static const AppIconData duration = HugeIcons.strokeRoundedClock01;
  static const AppIconData unknownType = HugeIcons.strokeRoundedHelpCircle;

  // Status and choices: always with words or a label beside them (A12).
  static const AppIconData check = HugeIcons.strokeRoundedTick02;
  static const AppIconData done = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const AppIconData notDone = HugeIcons.strokeRoundedCircle;
  static const AppIconData unselected = HugeIcons.strokeRoundedCircle;
  static const AppIconData clock = HugeIcons.strokeRoundedClock01;
  static const AppIconData waiting = HugeIcons.strokeRoundedHourglass;
  static const AppIconData paused = HugeIcons.strokeRoundedPauseCircle;
  static const AppIconData alert = HugeIcons.strokeRoundedAlertCircle;
  static const AppIconData info = HugeIcons.strokeRoundedInformationCircle;

  // Sync.
  static const AppIconData sync = HugeIcons.strokeRoundedArrowReloadHorizontal;
  static const AppIconData synced = HugeIcons.strokeRoundedCloudSavingDone01;
  static const AppIconData cloud = HugeIcons.strokeRoundedCloud;
  static const AppIconData offline = HugeIcons.strokeRoundedCloudOff;
  static const AppIconData uploading = HugeIcons.strokeRoundedCloudUpload;
  static const AppIconData refresh = HugeIcons.strokeRoundedRefresh;
  static const AppIconData update = HugeIcons.strokeRoundedDownload04;

  // Habits and their actions.
  static const AppIconData add = HugeIcons.strokeRoundedAdd01;
  static const AppIconData remove = HugeIcons.strokeRoundedMinusSign;
  static const AppIconData edit = HugeIcons.strokeRoundedPencilEdit01;
  static const AppIconData newHabit = HugeIcons.strokeRoundedTaskAdd01;
  static const AppIconData frequency = HugeIcons.strokeRoundedCalendar03;
  static const AppIconData startDate = HugeIcons.strokeRoundedCalendar01;
  static const AppIconData reminder = HugeIcons.strokeRoundedNotification01;
  static const AppIconData archive = HugeIcons.strokeRoundedArchive02;
  static const AppIconData restore = HugeIcons.strokeRoundedArchiveArrowUp;
  static const AppIconData archiveBox = HugeIcons.strokeRoundedPackage;
  static const AppIconData delete = HugeIcons.strokeRoundedDelete02;
  static const AppIconData leaf = HugeIcons.strokeRoundedLeaf01;

  // Rewards, privacy and profile.
  static const AppIconData rewards = HugeIcons.strokeRoundedAward01;
  static const AppIconData freeze = HugeIcons.strokeRoundedSnow;
  static const AppIconData privacy = HugeIcons.strokeRoundedShield01;
  static const AppIconData book = HugeIcons.strokeRoundedBook02;
  static const AppIconData camera = HugeIcons.strokeRoundedCamera01;
  static const AppIconData photoLibrary = HugeIcons.strokeRoundedImage01;
  static const AppIconData search = HugeIcons.strokeRoundedSearch01;
  static const AppIconData copy = HugeIcons.strokeRoundedCopy01;
  static const AppIconData show = HugeIcons.strokeRoundedView;
  static const AppIconData hide = HugeIcons.strokeRoundedViewOff;

  /// A53: a habit's own icon, from the whole Hugeicons set by its key; a null or unknown key
  /// shows [category]'s default (lib/domain/habit_icons.dart).
  static AppIconData habit(String? key, {String? category}) =>
      habitIconGlyphs[HabitIconCatalog.keyFor(key, category)]!;
}

/// A52: draws one [AppIcons] entry. Size and colour follow the surrounding [IconTheme] unless
/// given, as Material's Icon does. Without a [semanticLabel] it is invisible to screen readers
/// (the words beside it carry the meaning).
class AppIcon extends StatelessWidget {
  final AppIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final drawn = HugeIcon(icon: icon, size: size ?? theme.size ?? 24, color: color ?? theme.color);
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: drawn)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: drawn),
          );
  }
}

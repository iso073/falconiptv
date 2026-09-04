import 'package:flutter/material.dart';

import 'form_factor.dart';

/// Shared spacing for the 10-foot TV UI vs compact landscape phone.
abstract final class AppLayout {
  static bool phone(BuildContext context) => FormFactor.isPhoneOf(context);

  static EdgeInsets pagePadding(BuildContext context) => phone(context)
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
      : const EdgeInsets.symmetric(horizontal: 36, vertical: 22);

  static EdgeInsets glassPadding(BuildContext context) => phone(context)
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 28, vertical: 16);

  static double headerLogo(BuildContext context) => phone(context) ? 34 : 54;

  static double splashLogo(BuildContext context) => phone(context) ? 132 : 280;

  static double backButton(BuildContext context) => phone(context) ? 44 : 56;

  static double titleSize(BuildContext context) => phone(context) ? 20 : 26;

  static double profileCardWidth(BuildContext context) => phone(context) ? 176 : 230;

  static double categoryRail(BuildContext context) => phone(context) ? 128 : 280;

  static double seasonRail(BuildContext context) => phone(context) ? 140 : 240;

  static double channelPanel(BuildContext context) => phone(context) ? 300 : 460;

  static double tracksPanel(BuildContext context) => phone(context) ? 300 : 420;

  static int catalogColumns(BuildContext context) => phone(context) ? 5 : 4;

  static int searchColumns(BuildContext context) => phone(context) ? 6 : 5;

  static double catalogGap(BuildContext context) => phone(context) ? 8 : 12;

  static double catalogAspect(BuildContext context) => phone(context) ? 0.92 : 1;

  static int homeColumns() => 4;

  static double homeAspect(BuildContext context) => phone(context) ? 2.05 : 1.35;

  static double homeIcon(BuildContext context) => phone(context) ? 30 : 48;

  static double homeTitleSize(BuildContext context) => phone(context) ? 13 : 18;

  static double resumeHeight(BuildContext context) => phone(context) ? 64 : 92;
}

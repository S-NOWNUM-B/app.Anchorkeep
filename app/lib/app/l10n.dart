// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

/// Небольшой слой локализации для двух языков макета.
/// Тексты вызываются рядом с виджетом, чтобы оба варианта были видны при ревью.
String tr(BuildContext context, String ru, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : ru;

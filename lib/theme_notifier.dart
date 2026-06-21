import 'package:flutter/material.dart';

// This is now accessible by any screen without circular imports
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
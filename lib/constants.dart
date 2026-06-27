import 'package:flutter/material.dart';

class AppConstants {
  // --- PRICING ---
  static const double premium1MonthPrice = 500.0;
  static const double premium3MonthsPrice = 1000.0;
  static const String currencySymbol = '₹';

  // --- APP LIMITS ---
  static const int maxProfilePhotos = 6;
  static const int minAgeLimit = 18;
  static const int maxBioLength = 300;
  
  // --- SWIPE & MATCHING LOGIC ---
  static const int freeDailySwipes = 40;
  static const int paginationFetchLimit = 15;
  static const int paginationTriggerOffset = 3; // Fetch next page when 3 cards remain
  static const double defaultMaxDistanceKm = 50.0;

  // --- TIMERS & DELAYS ---
  static const Duration chatPollingInterval = Duration(seconds: 3);
  static const Duration imageTransitionDuration = Duration(milliseconds: 200);
  static const Duration snackbarDuration = Duration(seconds: 3);

  // --- CACHE TTLs ---
  static const Duration cacheTtlMasterData = Duration(hours: 24);
  static const Duration cacheTtlPremium = Duration(minutes: 5);
  static const Duration cacheTtlProfile = Duration(minutes: 5);
  static const Duration cacheTtlReasons = Duration(hours: 24);
  static const Duration cacheTtlNotifications = Duration(seconds: 30);
  static const Duration cacheTtlUnreadCount = Duration(seconds: 30);
  static const Duration cacheTtlChatMessages = Duration(hours: 1);
}
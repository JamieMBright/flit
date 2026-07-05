import 'package:flutter/material.dart';

/// Aviation rank for a player level — the single source of truth used by
/// the profile screen, license screen, and friend profile sheet.
({String title, IconData icon}) aviationRank(int level) {
  if (level >= 50) {
    return (title: 'Air Marshal', icon: Icons.stars);
  }
  if (level >= 40) {
    return (title: 'Wing Commander', icon: Icons.military_tech);
  }
  if (level >= 30) {
    return (title: 'Squadron Leader', icon: Icons.shield);
  }
  if (level >= 20) {
    return (title: 'Flight Lieutenant', icon: Icons.workspace_premium);
  }
  if (level >= 15) {
    return (title: 'Captain', icon: Icons.anchor);
  }
  if (level >= 10) {
    return (title: 'First Officer', icon: Icons.flight);
  }
  if (level >= 5) {
    return (title: 'Pilot Officer', icon: Icons.flight_takeoff);
  }
  if (level >= 3) {
    return (title: 'Cadet', icon: Icons.school);
  }
  return (title: 'Trainee', icon: Icons.person);
}

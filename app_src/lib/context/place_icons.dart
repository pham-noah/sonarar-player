library;

import 'package:flutter/material.dart';

const Map<String, IconData> kPlaceIcons = {
  'home': Icons.home_rounded,
  'work': Icons.work_rounded,
  'school': Icons.school_rounded,
  'gym': Icons.fitness_center_rounded,
  'food': Icons.restaurant_rounded,
  'cafe': Icons.local_cafe_rounded,
  'shop': Icons.shopping_bag_rounded,
  'station': Icons.train_rounded,
  'park': Icons.park_rounded,
  'hospital': Icons.local_hospital_rounded,
  'friend': Icons.people_rounded,
  'star': Icons.star_rounded,
};

const IconData kDefaultPlaceIcon = Icons.place_rounded;

bool isKnownPlaceIcon(String? name) => name != null && kPlaceIcons.containsKey(name);

IconData placeIconFor(String? name) =>
    name == null ? kDefaultPlaceIcon : (kPlaceIcons[name] ?? kDefaultPlaceIcon);

String placeIconLabel(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

import 'package:flutter/material.dart';
import 'package:flame/flame.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.images.prefix = 'assets/';
  runApp(const PixelMatchApp());
}

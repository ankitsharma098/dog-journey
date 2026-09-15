import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/bootstrap.dart';

void main() async {
  await bootstrap();
  runApp(const PawJourneyApp());
}

import 'package:flutter/material.dart';

import 'music_sources_page.dart';

/// The original Roam tab is kept as the third tab in Music's UI, but the
/// Spotify-backed discovery content is replaced with local / NAS / server
/// music source management.
class Roam extends StatelessWidget {
  const Roam({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MusicSourcesPage(),
    );
  }
}

import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang'),
      ),
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Tentang Aplikasi',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Chameleon adalah aplikasi galeri gratis dan open source yang memungkinkan Anda untuk menjelajahi, menyimpan, dan berbagi konten visual dengan mudah. Dibuat dengan ❤️ untuk komunitas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dependencies Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terima kasih kepada',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildDependencyItem(context,
                                    'flutter_launcher_icons', '^0.14.2'),
                                _buildDependencyItem(
                                    context, 'flutter_native_splash', '^2.4.4'),
                                _buildDependencyItem(
                                    context, 'cupertino_icons', '^1.0.8'),
                                _buildDependencyItem(
                                    context, 'dynamic_color', '^1.7.0'),
                                _buildDependencyItem(
                                    context, 'flutter_svg', '^2.0.17'),
                                _buildDependencyItem(context,
                                    'smooth_page_indicator', '^1.2.0+3'),
                                _buildDependencyItem(
                                    context, 'shared_preferences', '^2.3.5'),
                                _buildDependencyItem(context,
                                    'flutter_staggered_grid_view', '^0.7.0'),
                                _buildDependencyItem(
                                    context, 'url_launcher', '^6.3.1'),
                                _buildDependencyItem(
                                    context, 'firebase_core', '^3.10.1'),
                                _buildDependencyItem(
                                    context, 'firebase_auth', '^5.4.0'),
                                _buildDependencyItem(
                                    context, 'cloud_firestore', '^5.6.1'),
                                _buildDependencyItem(
                                    context, 'shimmer', '^3.0.0'),
                                _buildDependencyItem(context, 'uuid', '^4.5.1'),
                                _buildDependencyItem(
                                    context, 'image_picker', '^1.1.2'),
                                _buildDependencyItem(
                                    context, 'firebase_storage', '^12.4.0'),
                                _buildDependencyItem(
                                    context, 'intl', '^0.20.1'),
                                _buildDependencyItem(
                                    context, 'photo_view', '^0.15.0'),
                                _buildDependencyItem(
                                    context, 'provider', '^6.1.2'),
                                _buildDependencyItem(
                                    context, 'cached_network_image', '^3.4.1'),
                                _buildDependencyItem(
                                    context, 'share_plus', '^10.1.4'),
                                _buildDependencyItem(
                                    context, 'photo_manager', '^3.6.3'),
                                _buildDependencyItem(
                                    context, 'permission_handler', '^11.3.1'),
                                _buildDependencyItem(
                                    context, 'image_cropper', '^9.0.0'),
                                _buildDependencyItem(
                                    context, 'firebase_messaging', '^15.2.1'),
                                _buildDependencyItem(
                                    context,
                                    'firebase_core_platform_interface',
                                    '^5.4.0'),
                                _buildDependencyItem(context,
                                    'flutter_local_notifications', '^18.0.1'),
                                _buildDependencyItem(
                                    context, 'quick_actions', '^1.1.0'),
                                _buildDependencyItem(context,
                                    'flutter_staggered_animations', '^1.1.1'),
                                _buildDependencyItem(
                                    context, 'google_sign_in', '^6.2.2'),
                                _buildDependencyItem(context,
                                    'wallpaper_manager_flutter', '^0.0.2'),
                                _buildDependencyItem(
                                    context, 'flutter_pixel', '^0.0.3'),
                                _buildDependencyItem(
                                    context, 'universal_html', '^2.2.4'),
                                _buildDependencyItem(
                                    context, 'android_intent_plus', '^5.3.0'),
                                _buildDependencyItem(
                                    context, 'device_info_plus', '^11.3.0'),
                                _buildDependencyItem(
                                    context, 'open_file', '^3.5.10'),
                                _buildDependencyItem(
                                    context, 'hive_flutter', '^1.1.0'),
                                _buildDependencyItem(
                                    context, 'page_transition', '^2.2.1'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDependencyItem(
      BuildContext context, String name, String version) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            version,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

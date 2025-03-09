import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gnoo/main/pages/settings/about_page.dart';
import 'package:gnoo/main/pages/settings/donation_page.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
// import '../../auth/delete_account_screen.dart';
import '../../auth/login_screen.dart';
import 'settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // void _showAccountOptions(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     builder: (BuildContext context) {
  //       final colorScheme = Theme.of(context).colorScheme;
  //       return Container(
  //         decoration: BoxDecoration(
  //           color: colorScheme.surface,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  //         ),
  //         padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Pengaturan Akun',
  //               style: TextStyle(
  //                 fontSize: 24,
  //                 fontWeight: FontWeight.bold,
  //                 color: colorScheme.onSurface,
  //               ),
  //             ),
  //             SizedBox(height: 16),
  //             Text(
  //               'Pilih opsi yang tersedia di bawah ini',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 color: colorScheme.onSurfaceVariant,
  //               ),
  //             ),
  //             SizedBox(height: 24),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               children: [
  //                 TextButton(
  //                   onPressed: () {
  //                     Navigator.pop(context);
  //                     _showLogoutConfirmation(context);
  //                   },
  //                   style: TextButton.styleFrom(
  //                     foregroundColor: colorScheme.secondary,
  //                     padding:
  //                         EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(Icons.logout_outlined, size: 18),
  //                       SizedBox(width: 8),
  //                       Text('Logout'),
  //                     ],
  //                   ),
  //                 ),
  //                 FilledButton(
  //                   onPressed: () {
  //                     Navigator.pop(context);
  //                     _navigateToDeleteAccountPage(context);
  //                   },
  //                   style: FilledButton.styleFrom(
  //                     backgroundColor: colorScheme.errorContainer,
  //                     foregroundColor: colorScheme.onErrorContainer,
  //                     padding:
  //                         EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(
  //                         Icons.delete_outline,
  //                         size: 18,
  //                         color: colorScheme.onErrorContainer,
  //                       ),
  //                       SizedBox(width: 8),
  //                       Text('Hapus Akun'),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // void _navigateToDeleteAccountPage(BuildContext context) {
  //   Navigator.pop(context);
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
  //   );
  // }

  void _showLogoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Konfirmasi Logout',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Apakah Anda yakin ingin keluar dari akun?',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Batal'),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogout(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 18,
                          color: colorScheme.onErrorContainer,
                        ),
                        SizedBox(width: 8),
                        Text('Ya, Logout'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text('Sedang logout...', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 5));

    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('uid');

      navigator.pop();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print("Error during logout: $e");
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Gagal logout. Coba lagi.'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan'),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ThemeSettingsSection(),
                const SizedBox(height: 24),
                const ViewStyleSection(),
                const SizedBox(height: 24),
                const NavbarStyleSection(),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tentang Aplikasi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chameleon adalah aplikasi galeri gratis dan open source yang memungkinkan Anda untuk menjelajahi, menyimpan, dan berbagi konten visual dengan mudah. Dibuat dengan ❤️ untuk komunitas.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(
                            'https://github.com/alfahrelrifananda/chameleon')),
                        child: Row(
                          children: [
                            Icon(Icons.code,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Lihat Source code',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Versi: 1.0.0',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.sharedAxisVertical,
                                child: const DonationPage(),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite_border, size: 18),
                              SizedBox(width: 8),
                              Text('Donasi'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.sharedAxisVertical,
                                child: const AboutPage(),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Tentang'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        _showLogoutConfirmation(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout,
                            size: 18,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          const Text('Logout'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ViewStyleSection extends StatelessWidget {
  const ViewStyleSection({Key? key}) : super(key: key);

  Widget _buildStyleOptionCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w500 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gaya Tampilan Beranda',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Consumer<ViewStyleProvider>(
            builder: (context, viewStyleProvider, _) => Row(
              children: [
                _buildStyleOptionCard(
                  icon: Icons.dashboard_outlined,
                  label: 'Grid',
                  isSelected: viewStyleProvider.isGridStyle,
                  onTap: () => viewStyleProvider.setGridStyle(true),
                  context: context,
                ),
                const SizedBox(width: 16),
                _buildStyleOptionCard(
                  icon: Icons.view_agenda_outlined,
                  label: 'List',
                  isSelected: !viewStyleProvider.isGridStyle,
                  onTap: () => viewStyleProvider.setGridStyle(false),
                  context: context,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavbarStyleSection extends StatelessWidget {
  const NavbarStyleSection({Key? key}) : super(key: key);

  Widget _buildStyleOptionCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w500 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gaya Navigasi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          // Text(
          //   'Pilih tampilan navigasi yang Anda inginkan',
          //   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          //         color: Theme.of(context).colorScheme.onSurfaceVariant,
          //       ),
          // ),
          // const SizedBox(height: 16),
          Consumer<ViewStyleProvider>(
            builder: (context, viewStyleProvider, _) => Row(
              children: [
                _buildStyleOptionCard(
                  icon: Icons.blur_on,
                  label: 'Floating',
                  isSelected: viewStyleProvider.isFloatingNavbar,
                  onTap: () => viewStyleProvider.setFloatingNavbar(true),
                  context: context,
                ),
                const SizedBox(width: 16),
                _buildStyleOptionCard(
                  icon: Icons.tab,
                  label: 'Full Width',
                  isSelected: !viewStyleProvider.isFloatingNavbar,
                  onTap: () => viewStyleProvider.setFloatingNavbar(false),
                  context: context,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeSettingsSection extends StatelessWidget {
  const ThemeSettingsSection({Key? key}) : super(key: key);

  void _showColorPicker(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          final bool supportsDynamic =
              lightDynamic != null && darkDynamic != null;

          return StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      Text('Pilih warna tema',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      if (supportsDynamic)
                        SwitchListTile(
                          title: const Text('Dinamis'),
                          subtitle: const Text('Gunakan warna dari wallpaper'),
                          value: themeProvider.isDynamic,
                          onChanged: (value) {
                            setState(() {
                              themeProvider.setIsDynamic(value);
                            });
                            if (value) Navigator.pop(context);
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0)),
                        ),
                      if (!themeProvider.isDynamic || !supportsDynamic) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Colors.red,
                            Colors.pink,
                            Colors.purple,
                            Colors.deepPurple,
                            Colors.indigo,
                            Colors.blue,
                            Colors.lightBlue,
                            Colors.cyan,
                            Colors.teal,
                            Colors.green,
                            Colors.lightGreen,
                            Colors.lime,
                            Colors.yellow,
                            Colors.amber,
                            Colors.orange,
                            Colors.deepOrange,
                            Colors.brown,
                            Colors.blueGrey,
                          ]
                              .map((color) => InkWell(
                                    onTap: () {
                                      themeProvider.setPrimaryColor(color);
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: themeProvider.primaryColor ==
                                                  color
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: themeProvider.primaryColor == color
                                          ? Icon(
                                              Icons.check,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                            )
                                          : null,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Selesai'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Function(bool) onChanged,
  }) {
    return Builder(
      builder: (context) => Expanded(
        child: InkWell(
          onTap: () => onChanged(!isSelected),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w500 : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final bool supportsDynamic =
                lightDynamic != null && darkDynamic != null;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Warna & Tema',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildThemeOptionCard(
                        icon: Icons.brightness_auto_outlined,
                        label: 'System',
                        isSelected: themeProvider.themeMode == ThemeMode.system,
                        onChanged: (_) =>
                            themeProvider.setThemeMode(ThemeMode.system),
                      ),
                      const SizedBox(width: 16),
                      _buildThemeOptionCard(
                        icon: Icons.light_mode_outlined,
                        label: 'Terang',
                        isSelected: themeProvider.themeMode == ThemeMode.light,
                        onChanged: (_) =>
                            themeProvider.setThemeMode(ThemeMode.light),
                      ),
                      const SizedBox(width: 16),
                      _buildThemeOptionCard(
                        icon: Icons.dark_mode_outlined,
                        label: 'Gelap',
                        isSelected: themeProvider.themeMode == ThemeMode.dark,
                        onChanged: (_) =>
                            themeProvider.setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32.0),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Warna Primer'),
                      subtitle: Text(supportsDynamic && themeProvider.isDynamic
                          ? 'Dinamis'
                          : 'Kostum'),
                      trailing: (supportsDynamic && themeProvider.isDynamic)
                          ? null
                          : Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                      onTap: () => _showColorPicker(context),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32.0)),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

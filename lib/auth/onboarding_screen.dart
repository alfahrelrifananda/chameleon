// import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_transition/page_transition.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../pages/main_page.dart';
import 'login_screen.dart';
// import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final String _terms = """
Syarat Layanan Aplikasi Chameleon

Terakhir diperbarui: 30 Februari 2025

Selamat datang di aplikasi Chameleon! Kami senang Anda telah memilih untuk menggunakan layanan kami. Harap baca Syarat Layanan ini dengan seksama sebelum menggunakan aplikasi Chameleon. Dengan mengakses atau menggunakan aplikasi Chameleon, Anda setuju untuk terikat oleh Syarat Layanan ini. Jika Anda tidak setuju dengan Syarat Layanan ini, mohon jangan gunakan aplikasi Chameleon.

Penggunaan Aplikasi

Anda setuju untuk menggunakan aplikasi Chameleon hanya untuk tujuan yang sah dan sesuai dengan Syarat Layanan ini. Anda tidak boleh menggunakan aplikasi Chameleon untuk tujuan yang melanggar hukum atau dilarang oleh Syarat Layanan ini.

Konten Anda

Anda bertanggung jawab sepenuhnya atas konten yang Anda unggah atau bagikan melalui aplikasi Chameleon. Anda menjamin bahwa Anda memiliki semua hak yang diperlukan atas konten tersebut dan bahwa konten tersebut tidak melanggar hak kekayaan intelektual, privasi, atau hak lainnya dari pihak ketiga.

Privasi

Privasi Anda penting bagi kami. Kebijakan Privasi kami menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi pribadi Anda. Dengan menggunakan aplikasi Chameleon, Anda setuju dengan pengumpulan dan penggunaan informasi pribadi Anda sesuai dengan Kebijakan Privasi kami.

Perubahan pada Syarat Layanan

Kami berhak untuk mengubah Syarat Layanan ini kapan saja tanpa pemberitahuan sebelumnya. Perubahan tersebut akan berlaku efektif setelah dipublikasikan di aplikasi Chameleon.

Hukum yang Berlaku

Syarat Layanan ini akan diatur dan ditafsirkan sesuai dengan hukum Republik Indonesia.

Hubungi Kami

Jika Anda memiliki pertanyaan atau keluhan tentang Syarat Layanan ini, silakan hubungi kami di: pahrel1234@gmail.com
""";

  final String _privacy = """
Kebijakan Privasi Aplikasi Chameleon

Terakhir diperbarui: 30 Februari 2025

Kami menghargai privasi Anda dan berkomitmen untuk melindungi informasi pribadi Anda. Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi pribadi Anda saat Anda menggunakan aplikasi Chameleon.

Informasi yang Kami Kumpulkan

Kami dapat mengumpulkan informasi pribadi Anda saat Anda membuat akun, menggunakan aplikasi Chameleon, atau menghubungi kami. Informasi yang kami kumpulkan dapat mencakup nama Anda, alamat email, nomor telepon, dan informasi lain yang Anda berikan secara sukarela.

Bagaimana Kami Menggunakan Informasi Anda

Kami dapat menggunakan informasi pribadi Anda untuk berbagai tujuan, termasuk:

1. Menyediakan dan meningkatkan aplikasi Chameleon
2. Menanggapi pertanyaan atau permintaan Anda
3. Mengirimi Anda informasi tentang aplikasi Chameleon atau layanan kami
4. Menganalisis penggunaan aplikasi Chameleon
5. Mematuhi hukum dan peraturan yang berlaku

Bagaimana Kami Melindungi Informasi Anda

Kami mengambil langkah-langkah keamanan yang wajar untuk melindungi informasi pribadi Anda dari akses yang tidak sah, penggunaan, atau pengungkapan. Namun, tidak ada metode transmisi melalui internet atau penyimpanan elektronik yang 100% aman.

Perubahan pada Kebijakan Privasi

Kami berhak untuk mengubah Kebijakan Privasi ini kapan saja tanpa pemberitahuan sebelumnya. Perubahan tersebut akan berlaku efektif setelah dipublikasikan di aplikasi Chameleon.

Hubungi Kami

Jika Anda memiliki pertanyaan atau keluhan tentang Kebijakan Privasi ini, silakan hubungi kami di: pahrel1234@gmail.com
""";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUIOverlayStyle();
    });
  }

  void _setSystemUIOverlayStyle() {
    final colorScheme = Theme.of(context).colorScheme;
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: colorScheme.brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: colorScheme.brightness,
      systemNavigationBarColor: colorScheme.background,
      systemNavigationBarIconBrightness:
          colorScheme.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  OnboardingPage(
                    assetPath: 'assets/images/hello.svg',
                    title: 'Selamat Datang!',
                    description:
                        'Jelajahi, atur, dan bagikan foto Anda dalam satu tempat dengan antarmuka modern dan intuitif kami.',
                  ),
                  OnboardingPage(
                    assetPath:
                        'assets/images/uploads.svg', // Ganti dengan gambar yang relevan
                    title: 'Unggah',
                    description:
                        'Abadikan momen berharga Anda dengan mudah melalui fitur unggah gambar langsung dari galeri Anda.',
                  ),
                  OnboardingPage(
                    assetPath:
                        'assets/images/album.svg', // Ganti dengan gambar yang relevan
                    title: 'Album Foto',
                    description:
                        'Atur foto dan video Anda ke dalam album yang indah dan temukan kembali kenangan Anda dengan mudah.',
                  ),
                  OnboardingPage(
                    assetPath:
                        'assets/images/chat.svg', // Ganti dengan gambar yang relevan
                    title: 'Chat',
                    description:
                        'Tetap terhubung dengan teman dan keluarga melalui fitur chat yang intuitif dan menyenangkan.',
                  ),
                  OnboardingPage(
                    assetPath:
                        'assets/images/social.svg', // Ganti dengan gambar yang relevan
                    title: 'Interaksi Sosial',
                    description:
                        'Ekspresikan diri Anda dengan fitur like dan komentar postingan yang Anda sukai.',
                  ),
                  OnboardingPage(
                    assetPath: 'assets/images/ai.svg',
                    title: 'Asisten AI',
                    description:
                        'Dapatkan bantuan dan rekomendasi dari asisten AI yang siap membantu Anda kapan saja.',
                  ),
                  OnboardingPage(
                    assetPath: 'assets/images/splash.svg',
                    title: 'Siap untuk Memulai?',
                    description:
                        'Masuk atau daftar untuk menikmati semua fitur Chameleon dan terhubung dengan dunia!',
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _currentPage < 6
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text(
                            'Lanjutkan',
                            style: textTheme.bodyLarge?.copyWith(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // OutlinedButton(
                            //   style: OutlinedButton.styleFrom(
                            //     foregroundColor: colorScheme.primary,
                            //     minimumSize: const Size.fromHeight(56),
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(28),
                            //     ),
                            //     side: BorderSide(color: colorScheme.primary),
                            //   ),
                            //   onPressed: () async {
                            //     // Handle Skip
                            //     // Set the flag that onboarding is completed
                            //     final prefs =
                            //         await SharedPreferences.getInstance();
                            //     await prefs.setBool(
                            //         'onboardingCompleted', true);
                            //     // Navigate to MainPage (or Home Page)
                            //     Navigator.of(context).pushReplacement(
                            //       MaterialPageRoute(
                            //           builder: (context) =>
                            //               MainPage()), // Ganti MainPage() dengan halaman yang dituju jika perlu
                            //     );
                            //   },
                            //   // child: Text(
                            //   //   'Lewati',
                            //   //   style: textTheme.bodyLarge?.copyWith(
                            //   //     fontFamily: 'Outfit',
                            //   //     fontSize: 16,
                            //   //     fontWeight: FontWeight.w500,
                            //   //   ),
                            //   // ),
                            // ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: () async {
                                // Set the flag that onboarding is completed
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                    'onboardingCompleted', true);

                                Navigator.pushReplacement(
                                  context,
                                  PageTransition(
                                    type:
                                        PageTransitionType.sharedAxisHorizontal,
                                    child: LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Masuk',
                                style: textTheme.bodyLarge?.copyWith(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                SmoothPageIndicator(
                  controller: _pageController,
                  count: 7, // Sesuaikan dengan jumlah halaman Anda
                  effect: WormEffect(
                    dotColor: colorScheme.surfaceVariant,
                    activeDotColor: colorScheme.primary,
                    dotHeight: 8,
                    dotWidth: 8,
                    spacing: 8,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GestureDetector(
                      onTap: () {
                        _showTermsAndPrivacyBottomSheet(
                            context); // Show the bottom sheet on tap
                      },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: textTheme.bodySmall?.copyWith(
                            fontFamily: 'Outfit',
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                                text: 'Dengan melanjutkan, Anda menyetujui '),
                            TextSpan(
                              text: 'Syarat Layanan',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: colorScheme.primary,
                              ),
                            ),
                            TextSpan(text: ' dan '),
                            TextSpan(
                              text: 'Kebijakan Privasi',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: colorScheme.primary,
                              ),
                            ),
                            TextSpan(text: ' kami'),
                          ],
                        ),
                      )),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsAndPrivacyBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(32),
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Syarat Layanan & Kebijakan Privasi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Selamat datang di aplikasi Chameleon! Harap baca dengan seksama Syarat Layanan dan Kebijakan Privasi kami sebelum menggunakan aplikasi ini.',
                    textAlign: TextAlign.justify,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Syarat Layanan:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _terms,
                    textAlign: TextAlign.justify,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Kebijakan Privasi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _privacy,
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String assetPath;
  final String title;
  final String description;

  const OnboardingPage({
    Key? key,
    required this.assetPath,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 350,
            height: 350,
            padding: const EdgeInsets.all(8),
            child: FutureBuilder<String>(
              future: DefaultAssetBundle.of(context).loadString(assetPath),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                String svgContent = snapshot.data!;

                svgContent = svgContent
                    .replaceAll('#000000', theme.colorScheme.primary.toHex())
                    .replaceAll('#777777', theme.colorScheme.primaryContainer.toHex())
                    .replaceAll('#424242', theme.colorScheme.primaryContainer.toHex())
                    .replaceAll('#263238', '#263238')
                    .replaceAll('#FFB573', '#FFB573')
                    .replaceAll(
                        '#FFFFFF', theme.colorScheme.surfaceContainer.toHex());

                return SvgPicture.string(
                  svgContent,
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontFamily: 'NoyhR',
              color: colorScheme.onBackground,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              fontFamily: 'Outfit',
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

extension ColorExtension on Color {
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/painters/game_icons_painter.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/sticker_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _orbitController;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 12 detik per putaran orbit 4 koin
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Logo melayang naik-turun 12dp
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orbitController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    SoundService.instance.play(Sfx.uiTap);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) {
      context.go('/');
    }
  }

  void _onNextPressed() {
    SoundService.instance.play(Sfx.uiTap);
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Konten Slide yang Bisa Digeser (PageView)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildSlide0(t),
                  _buildSlide1(t),
                  _buildSlide2(t),
                ],
              ),
            ),

            // Bagian Bawah: Indikator Titik & Tombol Aksi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indikator Halaman (Memanjang jadi pil Tomat)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return GestureDetector(
                        key: Key('dot_$index'),
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isActive ? t.danger : t.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: t.ink,
                              width: 2.0,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Aksi Utama
                  StickerButton.large(
                    text: _currentPage < 2 ? 'Lanjut' : 'Mulai putar',
                    backgroundColor: t.danger,
                    textColor: t.ink,
                    onPressed: _onNextPressed,
                  ),
                  const SizedBox(height: 12),

                  // Tombol Lewati
                  GestureDetector(
                    onTap: _completeOnboarding,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Lewati',
                        style: t.bodyLargeBold.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Slide 1: Logo Melayang & Putar Terima Jajan
  Widget _buildSlide0(PutarTheme t) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Logo Melayang di Tengah dengan 4 Koin Mengorbit
          SizedBox(
            width: 270,
            height: 270,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Lingkaran Kuning Matahari Besar dengan Border Ink 3.5px
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: t.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t.ink,
                      width: t.heroBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadowColor,
                        offset: t.dialogShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),

                // Logo / Maskot Mochi di tengah melayang naik-turun 12dp
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: LogoWidget(
                    size: t.mascot != null ? 150 : 110,
                    strokeWidthRatio: 3.5,
                  ),
                ),

                // 4 Koin Warna-warni Mengorbit (12s per putaran)
                AnimatedBuilder(
                  animation: _orbitController,
                  builder: (context, child) {
                    final baseAngle = _orbitController.value * 2 * math.pi;
                    const orbitRadius = 118.0;

                    final coinColors = [
                      t.success,
                      t.danger,
                      t.accentBlue,
                      t.accentPurple,
                    ];

                    return Stack(
                      children: List.generate(4, (i) {
                        final angle = baseAngle + (i * math.pi / 2);
                        final x = 135.0 + orbitRadius * math.cos(angle);
                        final y = 135.0 + orbitRadius * math.sin(angle);

                        return Positioned(
                          left: x - 15,
                          top: y - 15,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: coinColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.ink,
                                width: t.borderWidth,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Judul: "Putar. \n Terima. \n Jajan."
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: t.displayLarge.copyWith(
                fontSize: 44,
                height: 1.1,
                letterSpacing: -1.2,
              ),
              children: [
                const TextSpan(text: 'Putar.\nTerima.\n'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.accentGreen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.ink, width: t.borderWidth),
                    ),
                    child: Text(
                      'Jajan.',
                      style: t.displayLarge.copyWith(
                        fontSize: 44,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Deskripsi
          Text(
            'Biar nggak bingung bahas budget pas\nngedate. Serahkan ke roda.',
            style: t.bodyMedium.copyWith(
              color: t.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Slide 2: Catat Cepat & Anti Boncos
  Widget _buildSlide1(PutarTheme t) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Ilustrasi Kartu Catatan Neo-brutalist
          SizedBox(
            width: 270,
            height: 270,
            child: Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.ink, width: t.heroBorderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: t.heroShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.success,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: t.ink, width: 2),
                          ),
                          child: Text(
                            'Lolos Budget!',
                            style: t.chipLabel.copyWith(
                              fontSize: 10,
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Sisa Saldo',
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Rp68.000',
                        style: t.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 2.5, color: t.ink),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sate Taichan',
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rp32.000',
                          style: t.bodySmall.copyWith(
                            fontWeight: t.weightExtraBold,
                            color: t.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Es Teh Manis',
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rp10.000',
                          style: t.bodySmall.copyWith(
                            fontWeight: t.weightExtraBold,
                            color: t.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Judul: "Catat Cepat. \n Pantau Sisa."
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: t.displayLarge.copyWith(
                fontSize: 38,
                height: 1.1,
                letterSpacing: -1.0,
              ),
              children: [
                const TextSpan(text: 'Catat Cepat.\nPantau Sisa.\n'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.success,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.ink, width: t.borderWidth),
                    ),
                    child: Text(
                      'Anti Boncos.',
                      style: t.displayLarge.copyWith(
                        fontSize: 38,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Deskripsi
          Text(
            'Catat setiap pengeluaran jajan secara realtime.\nSisa saldo terpantau aman tanpa pusing.',
            style: t.bodyMedium.copyWith(
              color: t.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Slide 3: 4 Pilihan Permainan Seru
  Widget _buildSlide2(PutarTheme t) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Showcase 4 Permainan Neo-brutalist (2x2)
          SizedBox(
            width: 270,
            height: 270,
            child: Center(
              child: SizedBox(
                width: 230,
                height: 230,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMiniGameBadge(t, 'Roda Putar', t.secondary, 'wheel'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniGameBadge(t, 'Kocok Dadu', t.accentBlue, 'dice'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMiniGameBadge(t, 'Gacha Kapsul', t.accentPink, 'capsule'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniGameBadge(t, 'Pilih Amplop', t.success, 'envelope'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Judul: "Banyak Pilihan. \n Lebih Seru."
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: t.displayLarge.copyWith(
                fontSize: 38,
                height: 1.1,
                letterSpacing: -1.0,
              ),
              children: [
                const TextSpan(text: 'Banyak Pilihan.\nLebih Seru.\n'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.accentPink,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.ink, width: t.borderWidth),
                    ),
                    child: Text(
                      'Mainkan!',
                      style: t.displayLarge.copyWith(
                        fontSize: 38,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Deskripsi
          Text(
            'Bosan sama roda? Ada kocok dadu, gacha kapsul,\ndan pilih amplop rahasia yang siap dimainkan!',
            style: t.bodyMedium.copyWith(
              color: t.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGameBadge(PutarTheme t, String title, Color color, String gameType) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: GameIconWidget(
              gameType: gameType,
              size: 40,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: t.chipLabel.copyWith(
              fontSize: 11,
              fontWeight: t.weightExtraBold,
              color: t.ink,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

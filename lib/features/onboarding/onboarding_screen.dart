import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/painters/game_icons_painter.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
    return Scaffold(
      backgroundColor: AppColors.cream,
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
                  _buildSlide0(),
                  _buildSlide1(),
                  _buildSlide2(),
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
                            color: isActive ? AppColors.tomat : AppColors.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppColors.ink,
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
                    backgroundColor: AppColors.tomat,
                    textColor: AppColors.ink,
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
                        style: AppTypography.bodyLargeBold.copyWith(
                          color: AppColors.textSecondary,
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
  Widget _buildSlide0() {
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
                    color: AppColors.matahari,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.ink,
                      width: 3.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(5, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),

                // Logo di tengah melayang naik-turun 12dp
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: const LogoWidget(
                    size: 110,
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
                      AppColors.mint,
                      AppColors.tomat,
                      AppColors.langit,
                      AppColors.lavender,
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
                                color: AppColors.ink,
                                width: 3.0,
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
              style: AppTypography.displayLarge.copyWith(
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
                      color: AppColors.lemon,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ink, width: 3),
                    ),
                    child: Text(
                      'Jajan.',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 44,
                        color: AppColors.ink,
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
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
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
  Widget _buildSlide1() {
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.ink, width: 3.5),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(6, 6),
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
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                          child: Text(
                            'Lolos Budget!',
                            style: AppTypography.chipLabel.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Sisa Saldo',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
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
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 2.5, color: AppColors.ink),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sate Taichan',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rp32.000',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.tomat,
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
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rp10.000',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.tomat,
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
              style: AppTypography.displayLarge.copyWith(
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
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ink, width: 3),
                    ),
                    child: Text(
                      'Anti Boncos.',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 38,
                        color: AppColors.ink,
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
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
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
  Widget _buildSlide2() {
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
                            child: _buildMiniGameBadge('Roda Putar', AppColors.matahari, 'wheel'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniGameBadge('Kocok Dadu', AppColors.langit, 'dice'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMiniGameBadge('Gacha Kapsul', AppColors.permen, 'capsule'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniGameBadge('Pilih Amplop', AppColors.mint, 'envelope'),
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
              style: AppTypography.displayLarge.copyWith(
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
                      color: AppColors.permen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ink, width: 3),
                    ),
                    child: Text(
                      'Mainkan!',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 38,
                        color: AppColors.ink,
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
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGameBadge(String title, Color color, String gameType) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
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
            style: AppTypography.chipLabel.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

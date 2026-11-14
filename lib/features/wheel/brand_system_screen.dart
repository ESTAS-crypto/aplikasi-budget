import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/putar_theme.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/painters/nav_icons_painter.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/in_app_toast.dart';
import '../../core/widgets/overbudget_dialog.dart';
import '../notifications/notification_service.dart';
import '../../core/utils/sound_service.dart';
import '../../core/notifications/notifications.dart';

/// Layar 5: Sistem Desain & Brand Identity (Referensi & Preview)
class BrandSystemScreen extends StatelessWidget {
  const BrandSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final isKucing = t.id == PutarTheme.kucingManis.id;
    final colors = isKucing
        ? [
            {'name': 'Sakura', 'hex': '#FF8FB1', 'color': t.accentCoral},
            {'name': 'Persik', 'hex': '#FFB997', 'color': t.accentOrange},
            {'name': 'Mentega', 'hex': '#FFE27A', 'color': t.accentYellow},
            {'name': 'Mint', 'hex': '#9BE8D0', 'color': t.accentMint},
            {'name': 'Langit', 'hex': '#A8D8FF', 'color': t.accentBlue},
            {'name': 'Lavender', 'hex': '#CDB4FF', 'color': t.accentPurple},
            {'name': 'Permen', 'hex': '#FFC8DD', 'color': t.accentPink},
            {'name': 'Pistachio', 'hex': '#C8F0A8', 'color': t.accentGreen},
          ]
        : [
            {'name': 'Tomat', 'hex': '#FF6B5A', 'color': t.accentCoral},
            {'name': 'Jeruk', 'hex': '#FF9F1C', 'color': t.accentOrange},
            {'name': 'Matahari', 'hex': '#FFD23F', 'color': t.accentYellow},
            {'name': 'Mint', 'hex': '#3DDBB0', 'color': t.accentMint},
            {'name': 'Langit', 'hex': '#6FB1FF', 'color': t.accentBlue},
            {'name': 'Lavender', 'hex': '#B8A4FF', 'color': t.accentPurple},
            {'name': 'Permen', 'hex': '#FF8FC0', 'color': t.accentPink},
            {'name': 'Lemon', 'hex': '#B8E986', 'color': t.accentGreen},
          ];

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.ink, width: 2.8),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(
                        painter: CustomBackIconPainter(color: t.ink),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logo Utama dalam Card Kuning Matahari
              StickerCard(
                backgroundColor: t.secondary,
                borderRadius: 28,
                borderWidth: t.heroBorderWidth,
                shadowOffset: t.heroShadowOffset,
                padding: const EdgeInsets.all(24),
                child: const LogoWidget(size: 130, strokeWidthRatio: 4.0),
              ),
              const SizedBox(height: 20),

              // Wordmark "putar jajan"
              Text(
                'putar jajan',
                style: t.displayLarge.copyWith(
                  fontSize: 38,
                  letterSpacing: -1.0,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 8),

              // Penjelasan Konsep Logo
              Text(
                isKucing
                    ? 'Mochi si kucing karamel penunggu jajan:\nteman imut yang ikut menjaga budgetmu.'
                    : 'Roda dengan satu irisan terlepas: bagian\nyang boleh kamu jajani.',
                textAlign: TextAlign.center,
                style: t.bodyMedium.copyWith(
                  color: t.textSecondary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // 3 Variasi Ikon Aplikasi
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: isKucing
                    ? [
                        _IconVariantCard(
                          bgColor: t.mascotEarPink,
                          sliceColor: t.surface,
                          furColor: t.mascotFur,
                          earPinkColor: t.mascotNose,
                        ),
                        const SizedBox(width: 14),
                        _IconVariantCard(
                          bgColor: t.surface,
                          sliceColor: t.secondary,
                          furColor: t.mascotFur,
                          earPinkColor: t.mascotEarPink,
                        ),
                        const SizedBox(width: 14),
                        _IconVariantCard(
                          bgColor: t.accentBlue,
                          sliceColor: t.danger,
                          furColor: t.mascotMuzzle,
                          earPinkColor: t.mascotNose,
                        ),
                      ]
                    : [
                        _IconVariantCard(bgColor: t.danger, sliceColor: t.surface),
                        const SizedBox(width: 14),
                        _IconVariantCard(bgColor: t.surface, sliceColor: t.secondary),
                        const SizedBox(width: 14),
                        _IconVariantCard(bgColor: t.accentPurple, sliceColor: t.danger),
                      ],
              ),
              const SizedBox(height: 20),

              // Nav Icons Preview Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(t.chipRadius),
                  border: Border.all(color: t.ink, width: t.borderWidth),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: WheelNavPainter(color: t.ink, hubColor: t.surface, style: t.navIconStyle))),
                    const SizedBox(width: 20),
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: ReceiptNavPainter(color: t.ink, cutoutColor: t.surface, style: t.navIconStyle))),
                    const SizedBox(width: 20),
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: HistoryNavPainter(color: t.ink, style: t.navIconStyle))),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Grid 8 Swatch Warna
              Wrap(
                spacing: 8,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: colors.map((c) {
                  final itemWidth = (MediaQuery.of(context).size.width - 48 - 24) / 4;
                  return SizedBox(
                    width: itemWidth.clamp(54.0, 85.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: c['color'] as Color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c['name'] as String,
                          style: t.bodySmall.copyWith(
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c['hex'] as String,
                          style: t.bodySmall.copyWith(
                            color: t.textSecondary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Bagian Uji Coba Notifikasi (Layar 3 & Layar 9)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Uji Coba Notifikasi (Layar 3 & 9)',
                  style: t.titleMedium.copyWith(
                    fontSize: 18,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Toast Mint ("Roda siap diputar!")',
                    backgroundColor: t.success,
                    textColor: t.ink,
                    onPressed: () {
                      InAppToast.show(context, message: t.text(PutarCopyKeys.wheelReady));
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Banner Atas (Peringatan 80%)',
                    backgroundColor: t.secondary,
                    textColor: t.ink,
                    onPressed: () {
                      NotificationCoordinator.instance.dispatch(
                        NotificationIntent.budget80(
                          scopeId: 'brand_demo',
                          sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
                          groupOrAppName: 'Putar Jajan',
                          remainingBudget: 18000,
                          totalBudget: 100000,
                          spentAmount: 82000,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Dialog Budget Lewat (100%+)',
                    backgroundColor: t.surface,
                    textColor: t.ink,
                    onPressed: () {
                      showOverbudgetDialog(context, excessAmount: 12000);
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Notifikasi Catat Jajan di HP Luar',
                    backgroundColor: t.accentPink,
                    textColor: t.ink,
                    onPressed: () async {
                      await NotificationService.instance.showExpenseLoggedNotification(
                        itemName: 'Seblak Pedas',
                        itemPrice: 32000,
                        remainingBudget: 68000,
                        totalSpent: 32000,
                        totalBudget: 100000,
                      );
                      if (context.mounted) {
                        InAppToast.show(context, message: 'Notifikasi jajan muncul di status bar!');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Kirim Notifikasi Status Bar (HP Luar)',
                    backgroundColor: t.accentPurple,
                    textColor: t.ink,
                    onPressed: () async {
                      await NotificationService.instance.showOngoingDateNotification(
                        remainingBudget: 36000,
                        spentAmount: 64000,
                        totalBudget: 100000,
                      );
                      await NotificationService.instance.showWarning80Notification(
                        remainingBudget: 18000,
                        spentPercentage: 0.82,
                      );
                      if (context.mounted) {
                        InAppToast.show(context, message: 'Notifikasi terkirim ke status bar!');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Catatan Kaki Design System
              Text(
                isKucing
                    ? 'Font Fredoka 400/500/600/700. Sudut membulat lembut dan bayangan vertikal 5px. Ikon Mochi adaptif ikut berganti saat tema aktif.'
                    : 'Font Bricolage Grotesque 500/700/800. Garis tebal 3px dan bayangan keras 4px. Ikon aplikasi adaptif, monokrom untuk tema Android 13.',
                textAlign: TextAlign.center,
                style: t.bodySmall.copyWith(
                  color: t.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconVariantCard extends StatelessWidget {
  final Color bgColor;
  final Color sliceColor;
  final Color? furColor;
  final Color? earPinkColor;

  const _IconVariantCard({
    required this.bgColor,
    required this.sliceColor,
    this.furColor,
    this.earPinkColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(t.smallCardRadius),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: [
          BoxShadow(color: t.ink, offset: t.miniShadowOffset, blurRadius: 0),
        ],
      ),
      alignment: Alignment.center,
      child: LogoWidget(
        size: 38,
        sliceColor: sliceColor,
        strokeWidthRatio: 4,
        furColor: furColor,
        earPinkColor: earPinkColor,
      ),
    );
  }
}

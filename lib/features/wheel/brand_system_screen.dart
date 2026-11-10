import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
    final colors = [
      {'name': 'Tomat', 'hex': '#FF6B5A', 'color': AppColors.tomat},
      {'name': 'Jeruk', 'hex': '#FF9F1C', 'color': AppColors.jeruk},
      {'name': 'Matahari', 'hex': '#FFD23F', 'color': AppColors.matahari},
      {'name': 'Mint', 'hex': '#3DDBB0', 'color': AppColors.mint},
      {'name': 'Langit', 'hex': '#6FB1FF', 'color': AppColors.langit},
      {'name': 'Lavender', 'hex': '#B8A4FF', 'color': AppColors.lavender},
      {'name': 'Permen', 'hex': '#FF8FC0', 'color': AppColors.permen},
      {'name': 'Lemon', 'hex': '#B8E986', 'color': AppColors.lemon},
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
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
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 2.8),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(
                        painter: CustomBackIconPainter(color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Logo Utama dalam Card Kuning Matahari
              StickerCard(
                backgroundColor: AppColors.matahari,
                borderRadius: 28,
                borderWidth: 3.5,
                shadowOffset: const Offset(6, 6),
                padding: const EdgeInsets.all(24),
                child: const LogoWidget(size: 130, strokeWidthRatio: 4.0),
              ),
              const SizedBox(height: 20),

              // Wordmark "putar jajan"
              Text(
                'putar jajan',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 38,
                  letterSpacing: -1.0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),

              // Penjelasan Konsep Logo
              Text(
                'Roda dengan satu irisan terlepas: bagian\nyang boleh kamu jajani.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // 3 Variasi Ikon Aplikasi
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconVariantCard(bgColor: AppColors.tomat, sliceColor: AppColors.surface),
                  const SizedBox(width: 14),
                  _IconVariantCard(bgColor: AppColors.surface, sliceColor: AppColors.matahari),
                  const SizedBox(width: 14),
                  _IconVariantCard(bgColor: AppColors.lavender, sliceColor: AppColors.tomat),
                ],
              ),
              const SizedBox(height: 20),

              // Nav Icons Preview Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.ink, width: 3),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: WheelNavPainter())),
                    SizedBox(width: 20),
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: ReceiptNavPainter())),
                    SizedBox(width: 20),
                    SizedBox(width: 24, height: 24, child: CustomPaint(painter: HistoryNavPainter())),
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
                            border: Border.all(color: AppColors.ink, width: 2.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c['name'] as String,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c['hex'] as String,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
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
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 18,
                    color: AppColors.ink,
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
                    backgroundColor: AppColors.mint,
                    textColor: AppColors.ink,
                    onPressed: () {
                      InAppToast.show(context, message: 'Roda siap diputar!');
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Banner Atas (Peringatan 80%)',
                    backgroundColor: AppColors.matahari,
                    textColor: AppColors.ink,
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
                    backgroundColor: AppColors.surface,
                    textColor: AppColors.ink,
                    onPressed: () {
                      showOverbudgetDialog(context, excessAmount: 12000);
                    },
                  ),
                  const SizedBox(height: 10),
                  StickerButton(
                    width: double.infinity,
                    height: 48,
                    text: 'Tes Notifikasi Catat Jajan di HP Luar',
                    backgroundColor: AppColors.permen,
                    textColor: AppColors.ink,
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
                    backgroundColor: AppColors.lavender,
                    textColor: AppColors.ink,
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
                'Font Bricolage Grotesque 500/700/800. Garis tebal 3px dan bayangan keras 4px. Ikon aplikasi adaptif, monokrom untuk tema Android 13.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
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

  const _IconVariantCard({required this.bgColor, required this.sliceColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      alignment: Alignment.center,
      child: LogoWidget(size: 38, sliceColor: sliceColor, strokeWidthRatio: 4),
    );
  }
}

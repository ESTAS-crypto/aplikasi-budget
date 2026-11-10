import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/notifications/coordinator/notification_coordinator.dart';
import '../../../core/notifications/models/notification_intent.dart';
import '../../../core/notifications/storage/notified_claim_store.dart';

/// Layar Observabilitas Notifikasi (Tersembunyi pada build debug sesuai UPDATE 2C Bagian 5)
/// Menampilkan 50 keputusan terakhir koordinator dan isi tabel klaim atomik `notified`
class NotificationDebugScreen extends ConsumerStatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  ConsumerState<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends ConsumerState<NotificationDebugScreen> {
  int _selectedTab = 0; // 0 = Keputusan, 1 = Tabel Notified
  List<NotifiedClaimRecord> _claims = [];
  bool _isLoadingClaims = false;

  @override
  void initState() {
    super.initState();
    _refreshClaims();
  }

  Future<void> _refreshClaims() async {
    setState(() => _isLoadingClaims = true);
    try {
      final store = SharedPrefsNotifiedClaimStore();
      final claims = await store.getRecentClaims(50);
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoadingClaims = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingClaims = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(notificationCoordinatorProvider);
    final decisions = coordinator.recentDecisions.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Debug Notifikasi',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.ink),
            tooltip: 'Segarkan',
            onPressed: () {
              setState(() {});
              _refreshClaims();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: AppColors.tomat),
            tooltip: 'Hapus Histori',
            onPressed: () async {
              coordinator.clearDecisionHistory();
              final store = SharedPrefsNotifiedClaimStore();
              await store.clearAll();
              setState(() {});
              await _refreshClaims();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.matahari : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Keputusan (${decisions.length})',
                        style: AppTypography.buttonSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 1);
                      _refreshClaims();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.matahari : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tabel Notified (${_claims.length})',
                        style: AppTypography.buttonSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildDecisionsView(decisions) : _buildClaimsView(),
    );
  }

  Widget _buildDecisionsView(List<NotificationDecision> decisions) {
    if (decisions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF5B4B7A)),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Keputusan',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Semua aktivitas notifikasi yang diproses oleh NotificationCoordinator akan dicatat di sini (maks 50).',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: const Color(0xFF5B4B7A)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: decisions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final d = decisions[index];
        return _buildDecisionCard(d);
      },
    );
  }

  Widget _buildDecisionCard(NotificationDecision d) {
    Color surfaceColor;
    switch (d.surface) {
      case NotificationSurface.banner:
        surfaceColor = AppColors.mint;
        break;
      case NotificationSurface.system:
        surfaceColor = AppColors.tomat;
        break;
      case NotificationSurface.dialog:
        surfaceColor = AppColors.lavender;
        break;
      case NotificationSurface.dropped:
        surfaceColor = const Color(0xFFE2DDF0);
        break;
    }

    final reasonColor = d.reason == NotificationDropReason.none
        ? AppColors.mint
        : (d.reason == NotificationDropReason.duplicate
            ? AppColors.tomat
            : (d.reason == NotificationDropReason.merged ? AppColors.langit : AppColors.matahari));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge Surface
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                child: Text(
                  d.surface.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Badge Reason
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reasonColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                child: Text(
                  'reason: ${d.reason.name}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Spacer(),

              // Timestamp
              Text(
                _formatTime(d.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B4B7A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.title.isNotEmpty ? d.title : (d.groupName ?? 'Notifikasi'),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'key: ${d.dedupeKey}\nsource: ${d.source.name}',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF4A3E60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsView() {
    if (_isLoadingClaims) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_claims.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_rows_outlined, size: 48, color: Color(0xFF5B4B7A)),
              const SizedBox(height: 12),
              Text(
                'Tabel Notified Kosong',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Setiap klaim atomik anti-double disimpan ke tabel lokal notified.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: const Color(0xFF5B4B7A)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _claims.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final claim = _claims[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                    child: Text(
                      claim.surface.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(claim.at),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5B4B7A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                claim.dedupeKey,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}


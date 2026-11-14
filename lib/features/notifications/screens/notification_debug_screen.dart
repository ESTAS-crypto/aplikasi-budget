import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/putar_theme.dart';
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
    final t = context.putarTheme;
    final coordinator = ref.watch(notificationCoordinatorProvider);
    final decisions = coordinator.recentDecisions.reversed.toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Debug Notifikasi',
          style: t.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: t.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: t.ink),
            tooltip: 'Segarkan',
            onPressed: () {
              setState(() {});
              _refreshClaims();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: t.danger),
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
              color: t.debugMutedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.ink, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? t.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Keputusan (${decisions.length})',
                        style: t.buttonSmall.copyWith(
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
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
                        color: _selectedTab == 1 ? t.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tabel Notified (${_claims.length})',
                        style: t.buttonSmall.copyWith(
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
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
      body: _selectedTab == 0 ? _buildDecisionsView(t, decisions) : _buildClaimsView(t),
    );
  }

  Widget _buildDecisionsView(PutarTheme t, List<NotificationDecision> decisions) {
    if (decisions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_outlined, size: 48, color: t.textSecondary),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Keputusan',
                style: t.titleMedium.copyWith(fontWeight: t.weightExtraBold),
              ),
              const SizedBox(height: 6),
              Text(
                'Semua aktivitas notifikasi yang diproses oleh NotificationCoordinator akan dicatat di sini (maks 50).',
                textAlign: TextAlign.center,
                style: t.bodySmall.copyWith(color: t.textSecondary),
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
        return _buildDecisionCard(t, d);
      },
    );
  }

  Widget _buildDecisionCard(PutarTheme t, NotificationDecision d) {
    Color surfaceColor;
    switch (d.surface) {
      case NotificationSurface.banner:
        surfaceColor = t.success;
        break;
      case NotificationSurface.system:
        surfaceColor = t.danger;
        break;
      case NotificationSurface.dialog:
        surfaceColor = t.accentPurple;
        break;
      case NotificationSurface.dropped:
        surfaceColor = t.debugHeaderBg;
        break;
    }

    final reasonColor = d.reason == NotificationDropReason.none
        ? t.success
        : (d.reason == NotificationDropReason.duplicate
            ? t.danger
            : (d.reason == NotificationDropReason.merged ? t.accentBlue : t.secondary));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.ink, width: 2),
        boxShadow: [
          BoxShadow(color: t.ink, offset: t.miniShadowOffset, blurRadius: 0),
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
                  border: Border.all(color: t.ink, width: 1.5),
                ),
                child: Text(
                  d.surface.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: t.ink,
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
                  border: Border.all(color: t.ink, width: 1.5),
                ),
                child: Text(
                  'reason: ${d.reason.name}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
              ),
              const Spacer(),

              // Timestamp
              Text(
                _formatTime(d.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: t.weightSemiBold,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.title.isNotEmpty ? d.title : (d.groupName ?? 'Notifikasi'),
            style: t.bodyMedium.copyWith(
              fontWeight: t.weightExtraBold,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'key: ${d.dedupeKey}\nsource: ${d.source.name}',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: t.ink.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsView(PutarTheme t) {
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
              Icon(Icons.table_rows_outlined, size: 48, color: t.textSecondary),
              const SizedBox(height: 12),
              Text(
                'Tabel Notified Kosong',
                style: t.titleMedium.copyWith(fontWeight: t.weightExtraBold),
              ),
              const SizedBox(height: 6),
              Text(
                'Setiap klaim atomik anti-double disimpan ke tabel lokal notified.',
                textAlign: TextAlign.center,
                style: t.bodySmall.copyWith(color: t.textSecondary),
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
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.ink, width: 2),
            boxShadow: [
              BoxShadow(color: t.ink, offset: t.miniShadowOffset, blurRadius: 0),
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
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.ink, width: 1.5),
                    ),
                    child: Text(
                      claim.surface.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(claim.at),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: t.weightSemiBold,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                claim.dedupeKey,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: t.weightBold,
                  color: t.ink,
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


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../fleet/data/models/device_model.dart';
import '../providers/share_provider.dart';

/// Modal bottom sheet for generating and sharing public tracking links (Feature F-37).
class ShareLinkBottomSheet extends StatelessWidget {
  final DeviceModel device;

  const ShareLinkBottomSheet({super.key, required this.device});

  /// Static helper to display the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required DeviceModel device,
    ShareProvider? provider,
  }) {
    final shareProvider = provider ?? context.read<ShareProvider>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => ChangeNotifierProvider<ShareProvider>.value(
        value: shareProvider,
        child: ShareLinkBottomSheet(device: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<ShareProvider>(
      builder: (context, provider, _) {
        final shareLink = provider.shareLink;

        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(
                            Icons.share_outlined,
                            color: Colors.blue.shade700,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bagikan Pelacakan Publik',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${device.name} • ${device.uniqueId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('share_sheet_close_button'),
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Duration Presets Section
                    const Text(
                      'Pilih Masa Berlaku Tautan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPresetChip(
                          context,
                          provider,
                          const Duration(hours: 1),
                          '1 Jam',
                          'share_preset_1h',
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          provider,
                          const Duration(hours: 6),
                          '6 Jam',
                          'share_preset_6h',
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          provider,
                          const Duration(hours: 24),
                          '24 Jam',
                          'share_preset_24h',
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          context,
                          provider,
                          const Duration(days: 7),
                          '7 Hari',
                          'share_preset_7d',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Conflict Banner (HTTP 409 Conflict)
                    if (provider.isConflict) ...[
                      Container(
                        key: const Key('share_sheet_conflict_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tautan berbagi aktif untuk armada ini sudah terdaftar di server. Silakan gunakan tautan yang ada atau tunggu hingga masa aktifnya berakhir.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (provider.errorMessage != null) ...[
                      // Generic Error Banner
                      Container(
                        key: const Key('share_sheet_error_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Generate Button
                    ElevatedButton.icon(
                      key: const Key('share_sheet_generate_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.link, size: 20),
                      label: Text(
                        provider.isLoading
                            ? 'Menghasilkan Tautan...'
                            : (shareLink != null
                                  ? 'Perbarui Tautan'
                                  : 'Buat Tautan Berbagi'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: provider.isLoading
                          ? null
                          : () => provider.generateLink(device.id),
                    ),
                    const SizedBox(height: 16),

                    // Generated Link Card (Visible when link is present)
                    if (shareLink != null) ...[
                      Container(
                        key: const Key('share_sheet_link_card'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.blue.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.blueGrey.shade800
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Tautan Publik Aktif',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatExpiration(shareLink.expiration),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // URL Container & Copy Action
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      shareLink.shareUrl,
                                      key: const Key('share_sheet_url_text'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  key: const Key('share_sheet_copy_button'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text(
                                    'Salin',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: shareLink.shareUrl),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(
                                      context,
                                    ).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Tautan berhasil disalin ke clipboard',
                                        ),
                                        backgroundColor: Colors.green.shade700,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Security Warning Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueGrey.shade900.withValues(alpha: 0.5)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Penerima tautan dapat melihat posisi langsung armada secara real-time hingga waktu kedaluwarsa tanpa perlu login.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(
    BuildContext context,
    ShareProvider provider,
    Duration preset,
    String label,
    String keyString,
  ) {
    final isSelected = provider.selectedDuration == preset;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        key: Key(keyString),
        borderRadius: BorderRadius.circular(8),
        onTap: () => provider.setDuration(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.shade700
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue.shade700
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade200 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatExpiration(DateTime exp) {
    final day = exp.day.toString().padLeft(2, '0');
    final month = exp.month.toString().padLeft(2, '0');
    final year = exp.year;
    final hour = exp.hour.toString().padLeft(2, '0');
    final minute = exp.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

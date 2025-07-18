import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/guest_limitation_service.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';

class GuestGenerationIndicator extends StatefulWidget {
  const GuestGenerationIndicator({super.key});

  @override
  State<GuestGenerationIndicator> createState() =>
      _GuestGenerationIndicatorState();
}

class _GuestGenerationIndicatorState extends State<GuestGenerationIndicator> {
  int _remainingGenerations = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRemainingGenerations();
  }

  Future<void> _loadRemainingGenerations() async {
    try {
      final service = GuestLimitationService.instance;
      final remaining = await service.getRemainingGuestGenerations();
      if (mounted) {
        setState(() {
          _remainingGenerations = remaining;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final service = GuestLimitationService.instance;

      // 🔄 Réinitialise le compteur à 0 (= 3 essais restants)
      await service.resetGuestGenerationsForTesting();

      // Recharge l’état local pour refléter immédiatement le changement
      await _loadRemainingGenerations();

      if (mounted) {
        context.pop(); // ferme la modale
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_remainingGenerations <= 0) {
      return ModalSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.limitReachedGenerations,
              style: context.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            12.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBtn(
                  label: context.l10n.exhaustedGenerations,
                  icon: Icons.block,
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  iconColor: Colors.red,
                  labelColor: Colors.red,
                ),
                IconBtn(
                  onPressed: _refresh,
                  icon: HugeIcons.solidRoundedRefresh,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ModalSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.remainingLimitGenerations,
              style: context.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            12.h,
            IconBtn(
              label: context.l10n.remainingGenerationsLabel(_remainingGenerations),
              // label: '$_remainingGenerations génération${_remainingGenerations > 1 ? 's' : ''} gratuite${_remainingGenerations > 1 ? 's' : ''}',
              icon: Icons.block,
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              iconColor: Colors.blue,
              labelColor: Colors.blue,
            ),
          ],
        ),
      );
  }
}

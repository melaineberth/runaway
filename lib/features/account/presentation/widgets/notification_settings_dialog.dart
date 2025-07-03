import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_event.dart';
import 'package:runaway/core/blocs/notification/notification_state.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class NotificationSettingsDialog extends StatelessWidget {
  const NotificationSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc()..add(NotificationInitializeRequested()),
      child: const _NotificationSettingsContent(),
    );
  }
}

class _NotificationSettingsContent extends StatelessWidget {
  const _NotificationSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.adaptiveBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.adaptivePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedNotification02,
                  color: context.adaptivePrimary,
                  size: 20,
                ),
              ),
              12.w,
              Expanded(
                child: Text(
                  context.l10n.notifications,
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  HugeIcons.strokeRoundedCancel01,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
          
          24.h,
          
          // Contenu
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state.isLoading && !state.isInitialized) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle principal
                  _buildNotificationToggle(context, state),
                  
                  if (state.notificationsEnabled) ...[
                    16.h,
                    _buildNotificationCategories(context),
                  ],
                  
                  if (state.errorMessage != null) ...[
                    16.h,
                    _buildErrorMessage(context, state.errorMessage!),
                  ],
                  
                  24.h,
                  
                  // Informations
                  _buildInfoSection(context, state),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationToggle(BuildContext context, NotificationState state) {
    return SquircleContainer(
      padding: const EdgeInsets.all(16),
      color: context.adaptiveBorder.withValues(alpha: 0.05),
      radius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications push',
                  style: context.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                4.h,
                Text(
                  'Recevoir des notifications sur vos activités',
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          12.w,
          if (state.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: state.notificationsEnabled,
              onChanged: (value) {
                context.notificationBloc.add(
                  NotificationToggleRequested(enabled: value),
                );
              },
              activeColor: context.adaptivePrimary,
            ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Types de notifications',
          style: context.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: context.adaptiveTextSecondary,
          ),
        ),
        12.h,
        _buildCategoryTile(
          context,
          title: 'Objectifs atteints',
          subtitle: 'Célébrer vos réussites',
          icon: HugeIcons.strokeRoundedTarget03,
          enabled: true,
        ),
        8.h,
        _buildCategoryTile(
          context,
          title: 'Nouveaux parcours',
          subtitle: 'Suggestions personnalisées',
          icon: HugeIcons.strokeRoundedRoute01,
          enabled: true,
        ),
        8.h,
        _buildCategoryTile(
          context,
          title: 'Rappels d\'activité',
          subtitle: 'Motivation quotidienne',
          icon: HugeIcons.strokeRoundedAlarmClock,
          enabled: false,
        ),
      ],
    );
  }
  
  Widget _buildCategoryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.adaptiveBorder.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: context.adaptiveTextSecondary,
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: null, // Désactivé pour cette démo
            activeColor: context.adaptivePrimary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            HugeIcons.strokeRoundedAlert02,
            color: Colors.red,
            size: 16,
          ),
          8.w,
          Expanded(
            child: Text(
              error,
              style: context.bodySmall?.copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(BuildContext context, NotificationState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.adaptiveBorder.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedInformationCircle,
                size: 16,
                color: context.adaptiveTextSecondary,
              ),
              8.w,
              Text(
                'Informations',
                style: context.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
          8.h,
          Text(
            'Les notifications vous aident à rester motivé et à suivre vos progrès. Vous pouvez modifier ces paramètres à tout moment.',
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (state.fcmToken != null) ...[
            8.h,
            Text(
              'État: ${state.notificationsEnabled ? "Activé" : "Désactivé"}',
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
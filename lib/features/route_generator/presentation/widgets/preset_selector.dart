import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import '../../domain/models/route_parameters.dart';

class PresetSelector extends StatelessWidget {
  final Function(String) onPresetSelected;
  final List<RouteParameters> favorites;
  final Function(int) onFavoriteSelected;
  final Function(int) onFavoriteDeleted;

  const PresetSelector({
    super.key,
    required this.onPresetSelected,
    required this.favorites,
    required this.onFavoriteSelected,
    required this.onFavoriteDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Text(
          'Presets recommandés',
          style: context.titleLarge,
        ),
        16.h,
        _PresetCard(
          title: 'Débutant',
          subtitle: 'Parcours facile de 5km',
          icon: HugeIcons.strokeRoundedMedal03,
          color: Colors.green,
          details: [
            'Distance: 5 km',
            'Terrain plat',
            'Zone urbaine',
          ],
          onTap: () => onPresetSelected('beginner'),
        ),
        12.h,
        _PresetCard(
          title: 'Intermédiaire',
          subtitle: 'Parcours modéré de 10km',
          icon: HugeIcons.strokeRoundedMedal02,
          color: Colors.orange,
          details: [
            'Distance: 10 km',
            'Terrain mixte',
            'Zone mixte',
          ],
          onTap: () => onPresetSelected('intermediate'),
        ),
        12.h,
        _PresetCard(
          title: 'Avancé',
          subtitle: 'Parcours difficile de 21km',
          icon: HugeIcons.strokeRoundedMedal01,
          color: Colors.red,
          details: [
            'Distance: 21 km',
            'Terrain vallonné',
            'Zone nature',
          ],
          onTap: () => onPresetSelected('advanced'),
        ),
        
        if (favorites.isNotEmpty) ...[
          32.h,
          Text(
            'Mes favoris',
            style: context.titleLarge,
          ),
          16.h,
          ...favorites.asMap().entries.map((entry) {
            final index = entry.key;
            final favorite = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _FavoriteCard(
                parameters: favorite,
                onTap: () => onFavoriteSelected(index),
                onDelete: () => onFavoriteDeleted(index),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic icon;
  final Color color;
  final List<String> details;
  final VoidCallback onTap;

  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.details,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: icon,
                color: color,
                size: 32,
              ),
            ),
            16.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  4.h,
                  Text(
                    subtitle,
                    style: context.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  8.h,
                  Wrap(
                    spacing: 12,
                    children: details.map((detail) => Text(
                      detail,
                      style: context.bodySmall?.copyWith(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final RouteParameters parameters;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FavoriteCard({
    required this.parameters,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedDelete02,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: parameters.activityType.icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              16.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${parameters.distanceKm} km - ${parameters.terrainType.title}',
                      style: context.titleSmall,
                    ),
                    4.h,
                    Text(
                      '${parameters.urbanDensity.title} • ${parameters.elevationGain.toStringAsFixed(0)}m',
                      style: context.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
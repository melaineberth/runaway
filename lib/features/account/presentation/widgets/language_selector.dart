import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/services/locale_service.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return ModalSheet(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Langue disponible",
                  style: context.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                3.h,
                Text(
                  'Choisissez votre préférence',
                  style: context.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    fontWeight: FontWeight.w500
                  ),
                ),
                20.h,
                Column(
                  children: [
                    ...LocaleService.supportedLocales.asMap().entries.map((entry) {
                      final i = entry.key;
                      final locale = entry.value;
                      final isSelected = locale == state.locale;
                      final languageName = LocaleService().getLanguageNativeName(locale);
          
                      return BlocListener<LocaleBloc, LocaleState>(
                        listener: (context, state) {
                          if (!state.isLoading && state.error == null) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == LocaleService.supportedLocales.length - 1 ? 0 : 12,
                          ),
                          child: _buildStyleTile(
                            context: context, 
                            name: languageName, 
                            flag: _getLanguageFlag(locale),
                            isSelected: isSelected, 
                            onTap: () {
                              if (!isSelected) {
                                context.read<LocaleBloc>().add(LocaleChanged(locale));
                              }
                            },
                          ),
                        ),
                      );
                    })
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }

  String _getLanguageFlag(Locale locale) {
    switch (locale.languageCode) {
      case 'fr':
        return '🇫🇷';
      case 'en':
        return '🇺🇸';
      default:
        return '🌍';
    }
  }

  Widget _buildStyleTile({
    required BuildContext context,
    required String name,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SquircleContainer(
      onTap: onTap,
      radius: 40,
      color: Colors.white10,
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icône du style
          Row(
            children: [
              SquircleContainer(
                padding: EdgeInsets.all(8),
                radius: 18,
                color: Colors.black.withValues(alpha: 0.1),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
                
              15.w,
                
              // Informations du style
              Text(
                name,
                style: context.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
            
          // Indicateur de sélection
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected 
                  ? AppColors.primary
                  : Colors.transparent,
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    HugeIcons.solidRoundedTick02,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
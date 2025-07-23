import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/services/locale_service.dart';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.availableLanguage,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextPrimary,
                ),
              ),
              2.h,
              Text(
                context.l10n.selectPreferenceLanguage,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextSecondary,
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
          
                    final isSelected = state.locale.languageCode == locale.languageCode;
                    final languageName = LocaleService().getLanguageNativeName(locale);
                    
                    return MultiBlocListener(
                      listeners: [
                        // 🔧 FIX: Gestion séparée du changement de langue
                        BlocListener<LocaleBloc, LocaleState>(
                          listenWhen: (previous, current) => 
                              previous.locale != current.locale && !current.isLoading,
                          listener: (context, state) {
                            // 🔧 Attendre la fin du frame avant de fermer la modal
                            SchedulerBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            });
                          },
                        ),
                      ],
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: i == LocaleService.supportedLocales.length - 1 ? 0 : 10,
                        ),
                        child: _buildStyleTile(
                          context: context, 
                          name: languageName, 
                          flag: _getLanguageFlag(locale),
                          isSelected: isSelected, 
                          onTap: () {
                            if (!isSelected) {
                              context.localeBloc.add(LocaleChanged(locale));
                              
                              // 🆕 Délai pour voir la transition
                              Future.delayed(const Duration(milliseconds: 150), () {
                                if (context.mounted && Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              });
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
      case 'it':
        return '🇮🇹';
      case 'es':
        return '🇪🇸';
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
      radius: 50,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icône du style
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 25),
                ),
              ),
                
              10.w,
                
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? context.adaptivePrimary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                      ? context.adaptivePrimary
                      : context.adaptiveBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      HugeIcons.solidRoundedTick02,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
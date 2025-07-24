import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalSheet(
          child: BlocBuilder<ThemeBloc, ThemeState>(
            // ✅ Ne rebuild que si le mode ou le status loading change
            buildWhen: (previous, current) =>
              previous.themeMode != current.themeMode ||
              previous.isLoading != current.isLoading,
          
            builder: (context, state) {
              if (state.isLoading) {
                return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.theme,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                  2.h,
                  Text(
                    context.l10n.selectPreferenceTheme,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  20.h,
                  Column(
                    children: [
                      ...AppThemeMode.values.asMap().entries.map((entry) {
                        final i = entry.key;
                        final themeMode = entry.value;
                        final isSelected = themeMode == state.themeMode;
                        final themeName = _getThemeName(context, themeMode);
                        final isDefault = themeMode == AppThemeMode.auto;
                        
                        return MultiBlocListener(
                          listeners: [
                            BlocListener<ThemeBloc, ThemeState>(
                              // ✅ Écouter seulement quand le theme change (et pas en loading)
                              listenWhen: (previous, current) => 
                                  previous.themeMode != current.themeMode && !current.isLoading,
              
                              listener: (context, state) {
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
                              bottom: i == AppThemeMode.values.length - 1 ? 0 : 10,
                            ),
                            child: _buildThemeTile(
                              context: context, 
                              name: themeName, 
                              icon: _getThemeIcon(themeMode),
                              isSelected: isSelected, 
                              isDefault: isDefault,          
                              onTap: () {
                                if (!isSelected) {
                                  context.themeBloc.add(ThemeChanged(themeMode));
                                  
                                  if (context.mounted && Navigator.of(context).canPop()) {
                                    context.pop();
                                    context.pop();
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      })
                    ],
                  )
                ],
              );
            }
          ),
        ),
        Positioned(
          right: 15,
          top: 15,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
                reverseCurve: Curves.easeOut,
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: IconBtn(
              backgroundColor: Colors.transparent,
              icon: HugeIcons.solidRoundedCancelCircle,
              iconColor: context.adaptiveDisabled.withValues(alpha: 0.4),
              onPressed: () => context.pop(),
            ),
          ),
        )
      ],
    );
  }

  String _getThemeName(BuildContext context, AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.auto:
        return context.l10n.autoTheme;
      case AppThemeMode.light:
        return context.l10n.lightTheme;
      case AppThemeMode.dark:
        return context.l10n.darkTheme;
    }
  }

  IconData _getThemeIcon(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.auto:
        return HugeIcons.solidRoundedSmartPhone01;
      case AppThemeMode.light:
        return HugeIcons.solidRoundedSun03;
      case AppThemeMode.dark:
        return HugeIcons.solidRoundedMoon02;
    }
  }

  Widget _buildThemeTile({
    required BuildContext context,
    required String name,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDefault = false,
  }) {
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SquircleContainer(
                radius: 30,
                isGlow: true,
                color: context.adaptivePrimary,
                padding: const EdgeInsets.all(15),
                child: Icon(
                  icon, 
                  color: Colors.white, 
                  size: 25,
                ),
              ),
                
              15.w,

              Text(
                name,
                style: context.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (isDefault) ...[
                10.w,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.adaptiveBorder.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    context.l10n.byDefault,        // ex. « Par défaut »
                    style: context.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
            
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
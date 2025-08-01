import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/utils/connectivity_helper.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:runaway/features/account/presentation/widgets/language_selector.dart';
import 'package:runaway/features/account/presentation/widgets/theme_selector.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/credits/presentation/screens/credit_plans_screen.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'package:url_launcher/url_launcher.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Ajouter cette variable pour gérer le chargement
  bool _isProfileUpdating = false;

  // Variables pour tracker les opérations en cours
  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;

  bool _isImageLoading = true;
  bool _hasImageError = false;

  late String _screenLoadId;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _screenLoadId = context.trackScreenLoad('account_screen');

    // Vérifier la cohérence des données utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LogConfig.logInfo('💳 Vérification cohérence utilisateur depuis AccountScreen');
        
        // Vérifier et corriger si nécessaire
        context.ensureUserDataConsistency().then((_) {
          // Puis déclencher le refresh normal
          if (mounted) {
            context.refreshCreditData();
            context.finishScreenLoad(_screenLoadId);
          }
        });
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void launchURL() async {
    final Uri url = Uri.parse('https://x.com/elonmusk');
    if (!await launchUrl(url)) {
      if (mounted) {
        throw Exception(context.l10n.couldNotLaunchUrl(url.toString()));
      }
    }
  }

  void openStore() {
    if (Platform.isAndroid || Platform.isIOS) {
      final appId =
          Platform.isAndroid ? 'YOUR_ANDROID_PACKAGE_ID' : '6748111941';
      final url = Uri.parse(
        Platform.isAndroid
            ? "market://details?id=$appId"
            : "https://apps.apple.com/app/id$appId",
      );
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void launchEmail() async {
    final String email = 'service@trailix.app';
    final String subject = Uri.encodeComponent(
      context.l10n.supportEmailSubject,
    );

    final String body = Uri.encodeComponent(context.l10n.supportEmailBody);

    final String url = 'mailto:$email?subject=$subject&body=$body';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.couldNotLaunchEmailApp,
          ),
        );
      }
    }
  }

  // Méthodes pour tracker les actions du compte
  void _trackAccountAction(String action, {Map<String, dynamic>? data}) {
    MonitoringService.instance.recordMetric(
      'account_action',
      1,
      tags: {
        'action': action,
        'screen': 'account',
        ...?data,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MonitoredScreen(
      screenName: 'account_screen',
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          // Gérer la fin du chargement du profil
          if (authState is Authenticated && _isProfileUpdating) {
            setState(() {
              _isProfileUpdating = false;
            });
          }

          // Gérer le succès de la déconnexion
          if (authState is Unauthenticated && _isLoggingOut) {
            setState(() {
              _isLoggingOut = false;
            });
            
            // Afficher le snackbar de succès pour la déconnexion
            if (context.mounted) {
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: context.l10n.logoutSuccess,
                ),
              );
            }

            // Redirection vers la page d'accueil avec délai pour voir le snackbar
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (context.mounted) {
                context.go('/home');
              }
            });
            return; // empêcher l'exécution du bloc générique
          }

          // Gérer le succès de la suppression de compte
          if (authState is Unauthenticated && _isDeletingAccount) {
            setState(() {
              _isDeletingAccount = false;
            });
            
            // Afficher le snackbar de succès pour la suppression
            if (context.mounted) {
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: context.l10n.deleteAccountSuccess,
                ),
              );
            }

            // Redirection vers la page d'accueil avec délai pour voir le snackbar
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (context.mounted) {
                context.go('/home');
              }
            });
            return; //empêcher l'exécution du bloc générique
          }

          // Redirection automatique si ce n'est pas une déconnexion/suppression intentionnelle
          if (authState is Unauthenticated && !_isLoggingOut && !_isDeletingAccount) {
            print('🧭 Utilisateur déconnecté (autre raison), redirection vers HomeScreen');

            // Fermer la modal AccountScreen si elle existe
            if (context.mounted && Navigator.canPop(context)) {
              context.pop();
            }
            
            // Petit délai pour laisser l'animation se terminer
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                context.go('/home');
              }
            });
          }

          // Gérer les erreurs d'authentification
          if (authState is AuthError) {
            // Réinitialiser les états de chargement en cas d'erreur
            if (_isLoggingOut) {
              setState(() {
                _isLoggingOut = false;
              });
            }
            if (_isDeletingAccount) {
              setState(() {
                _isDeletingAccount = false;
              });
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          child: Container(
            color: context.adaptiveBackground,
            child: BlocBuilder<AuthBloc, AuthState>(
              // Empêcher le rebuild pendant la mise à jour du profil
              buildWhen: (previous, current) {
                if (_isProfileUpdating) return false;
                return true;
              },
              builder: (_, authState) {          
                // Si l'utilisateur est connecté, afficher le contenu
                if (authState is Authenticated) {
                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsetsGeometry.only(
                          top: kToolbarHeight * 1.2,
                          left: 20.0,
                          right: 20.0,
                        ),
                        child: _buildAppBar(authState),
                      ),
                      Expanded(
                        child: _buildAuthenticatedView(authState),
                      ),
                    ],
                  );
                }
            
                return _buildEmptyUnauthenticated();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(Authenticated authState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconBtn(
          padding: 8.0,
          onPressed: () => context.pop(),
          backgroundColor: Colors.transparent,
          child: Icon(
            HugeIcons.strokeStandardArrowDown01,
            color: context.adaptiveWhite,
            size: 28,
          ),
        ),
        Text(
          context.l10n.account,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        IconBtn(
          padding: 8.0,
          onPressed: () => _navigateToEditProfile(context, authState.profile), // Nouvelle méthode
          backgroundColor: context.adaptivePrimary,
          child: Icon(
            HugeIcons.solidRoundedAccountSetting03,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyUnauthenticated() {
    return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
              child: BlurryPage(
                children: [ 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: HSLColor.fromColor(context.adaptivePrimary).withLightness(0.8).toColor(),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                spreadRadius: 2,
                                blurRadius: 30,
                                offset: Offset(0, 0), // changes position of shadow
                              ),
                            ],
                          ),
                        ),
              
                        20.h,
              
                        Column(
                          spacing: 5.0,
                          children: [
                            SquircleContainer(
                              width: 120,
                              radius: 20.0,
                              height: 25,
                              color: context.adaptivePrimary,
                            ),
                            SquircleContainer(
                              width: 100,
                              radius: 20.0,
                              height: 20,
                              color: context.adaptivePrimary,
                            ),
                          ],
                        ),
              
                        30.h,
              
                        IconBtn(
                          padding: 10,
                          trailling: HugeIcons.strokeStandardArrowRight01,
                          iconSize: 20,
                          label: context.l10n.editProfile,
                          textStyle: context.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.adaptivePrimary,
                          ),
                          iconColor: context.adaptivePrimary,
                          backgroundColor: context.adaptivePrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      );
  }

  Widget _buildAuthenticatedView(Authenticated authState) {
    final user = authState.profile;

    return BlurryPage(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      children: [
        50.h,
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                child: _buildHeaderAccount(
                  ctx: context,
                  user: user,
                  color: Color(int.parse(user.color)),
                ),
              ),
            );
          }
        ),

        50.h,
    
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: Platform.isAndroid ? MediaQuery.of(context).padding.bottom : 0.0,
                  ),
                  child: _buildSettingContent(),
                ),
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildSettingContent() {
    return Column(
      children: [
        // Preferences settings
        _buildSettingCategory(
          context,
          title: context.l10n.preferences,
          children: [
            // Language selector
            _buildSettingTile(
              context,
              label: context.l10n.language,
              icon: HugeIcons.strokeRoundedLanguageSkill,
              onTap: () => _navigateToEditLanguage(),
              child: IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                label: context.l10n.currentLanguage,
                iconSize: 19,
                labelColor: context.adaptiveTextSecondary,
                iconColor: context.adaptiveTextSecondary,
                trailling: HugeIcons.strokeStandardArrowRight01,
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
      
            // Notification switch
            // _buildSettingTile(
            //   context,
            //   label: context.l10n.notifications,
            //   icon: HugeIcons.strokeRoundedNotification02,
            //   child: BlocBuilder<NotificationBloc, NotificationState>(
            //     builder: (context, notificationState) {
            //       Color getColor(Set<WidgetState> states) {
            //         // Vérifier si le switch est désactivé
            //         if (states.contains(WidgetState.disabled)) {
            //           return context.adaptiveDisabled.withValues(alpha: 0.5);
            //         }
                    
            //         // Vérifier si le switch est activé (ON)
            //         if (states.contains(WidgetState.selected)) {
            //           return context.adaptivePrimary; // Couleur quand activé
            //         }
                    
            //         // État par défaut (OFF)
            //         return context.adaptiveDisabled; // Couleur quand désactivé
            //       }
    
            //       // Afficher un indicateur de chargement si en cours d'initialisation
            //       if (notificationState.isLoading &&
            //           !notificationState.isInitialized) {
            //         return SizedBox(
            //           width: 20,
            //           height: 20,
            //           child: CircularProgressIndicator(
            //             strokeWidth: 2,
            //             valueColor: AlwaysStoppedAnimation<Color>(
            //               context.adaptivePrimary,
            //             ),
            //           ),
            //         );
            //       }
      
            //       return Switch(
            //         value: notificationState.notificationsEnabled,
            //         inactiveThumbColor: context.adaptiveDisabled,
            //         // inactiveTrackColor: Colors.red,
            //         trackOutlineColor: WidgetStateProperty.resolveWith(getColor),
            //         activeColor: context.adaptivePrimary,
            //         onChanged: notificationState.isLoading
            //           ? null
            //           : (value) {
            //             HapticFeedback.mediumImpact();
    
            //             // Déclencher l'événement pour basculer les notifications
            //             context.notificationBloc.add(
            //               NotificationToggleRequested(
            //                 enabled: value,
            //               ),
            //             );
            //           },
            //       );
            //     },
            //   ),
            // ),
      
            // Theme selector
            _buildSettingTile(
              context,
              label: context.l10n.theme,
              icon: HugeIcons.strokeRoundedPaintBoard,
              onTap: () => _navigateToEditTheme(),
              child: BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  String currentThemeLabel;
                  switch (themeState.themeMode) {
                    case AppThemeMode.auto:
                      currentThemeLabel = context.l10n.autoTheme;
                      break;
                    case AppThemeMode.light:
                      currentThemeLabel = context.l10n.lightTheme;
                      break;
                    case AppThemeMode.dark:
                      currentThemeLabel = context.l10n.darkTheme;
                      break;
                  }
      
                  return IconBtn(
                    padding: 0.0,
                    backgroundColor: Colors.transparent,
                    label: currentThemeLabel,
                    iconSize: 19,
                    labelColor: context.adaptiveTextSecondary,
                    iconColor: context.adaptiveTextSecondary,
                    trailling: HugeIcons.strokeStandardArrowRight01,
                    textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      
        50.h,
      
        // Resources settings
        _buildSettingCategory(
          context,
          title: context.l10n.resources,
          children: [
            _buildSettingTile(
              context,
              label: context.l10n.contactSupport,
              icon: HugeIcons.strokeRoundedMail02,
              onTap: () => launchEmail(),
              child: HugeIcon(
                icon: HugeIcons.strokeStandardArrowRight01,
                color: context.adaptiveTextSecondary,
                size: 19,
              ),
            ),
            _buildSettingTile(
              context,
              label: context.l10n.rateInStore,
              icon: HugeIcons.strokeRoundedStar,
              onTap: () => openStore(),
              child: IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                iconSize: 19,
                iconColor: context.adaptiveTextSecondary,
                trailling: HugeIcons.strokeStandardArrowRight01,
              ),
            ),
            _buildSettingTile(
              context,
              label: context.l10n.followOnX,
              icon: HugeIcons.strokeRoundedNewTwitter,
              onTap: () => launchURL(),
              child: IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                iconSize: 19,
                iconColor: context.adaptiveTextSecondary,
                trailling: HugeIcons.strokeStandardArrowRight01,
              ),
            ),
          ],
        ),
      
        50.h,
      
        // Account settings
        _buildSettingCategory(
          context,
          title: context.l10n.account,
          children: [
            // Disconnect user
            _buildCreditsTile(),
    
            // Disconnect user
            _buildSettingTile(
              context,
              label: context.l10n.disconnect,
              icon: HugeIcons.strokeRoundedLogoutSquare02,
              onTap: () => _showLogoutDialog(context),
              child: IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                iconSize: 19,
                labelColor: context.adaptiveTextSecondary,
                iconColor: context.adaptiveTextSecondary,
                trailling: HugeIcons.strokeStandardArrowRight01,
              ),
            ),
      
            // Delete account
            _buildSettingTile(
              context,
              label: context.l10n.deleteProfile,
              icon: HugeIcons.strokeRoundedDelete02,
              iconColor: Colors.red,
              labelColor: Colors.red,
              onTap: () => _showDeleteAccountDialog(context),
              child: IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                iconSize: 19,
                iconColor: Colors.red,
                trailling: HugeIcons.strokeStandardArrowRight01,
              ),
            ),
          ],
        ),
      
        70.h,
      
        _buildAppVersion(),

        70.h
      
      ],
    );
  }

  Widget _buildCreditsTile() {
    // 🆕 Utilisation d'AppDataBloc au lieu de CreditsBloc directement
    return BlocBuilder<AppDataBloc, AppDataState>(
      builder: (context, appDataState) {
        // Déterminer l'affichage selon l'état des données dans AppDataBloc
        String creditsDisplay;
        bool isLoading = false;

        if (!appDataState.isCreditDataLoaded && appDataState.isLoading) {
          // Chargement en cours
          isLoading = true;
          creditsDisplay = '--';
        } else if (appDataState.hasCreditData) {
          // Données disponibles - affichage immédiat
          final credits = appDataState.availableCredits;
          creditsDisplay = credits.toString();
        } else if (appDataState.lastError != null) {
          // Erreur
          creditsDisplay = 'Erreur';
        } else {
          // État initial ou pas de données
          creditsDisplay = '--';
        }

        return _buildSettingTile(
          context,
          label: context.l10n.manageCredits,
          icon: HugeIcons.strokeRoundedWallet05,
          onTap: isLoading ? null : () => _navigateToCredits(),
          child: Row(
            children: [
              // Indicateur de statut visuel
              if (appDataState.hasCreditData)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: appDataState.hasCredits 
                      ? Colors.green 
                      : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              
              // Affichage des crédits
              Text(
                creditsDisplay,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              10.w,
              
              IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                iconSize: 19,
                iconColor: context.adaptiveTextSecondary,
                trailling: HugeIcons.strokeStandardArrowRight01,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppVersion() {
    return Column(
      children: [
        SizedBox(
          width: 45,
          height: 45,
          child: SvgPicture.asset(
            "assets/img/LOGO_SYMBOLE.svg",
            colorFilter: ColorFilter.mode(
              context.adaptiveBorder.withValues(alpha: 0.2),
              BlendMode.srcIn,
            ),
            semanticsLabel: 'Trailix Logo',
          ),
        ),
        15.h,
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final packageInfo = snapshot.data!;
              return Text(
                "Version ${packageInfo.version} (${packageInfo.buildNumber})",
                style: context.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.adaptiveBorder.withValues(alpha: 0.2),
                ),
              );
            }
            return Text(
              "Version --",
              style: context.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.adaptiveBorder.withValues(alpha: 0.2),
              ),
            );
          },
        ),
        Text.rich(
          TextSpan(
            text: context.l10n.termsAndPrivacy,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(Uri.parse("https://trailix.app/fr/legal/terms/site.html")),
          ),
          style: context.bodySmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.adaptiveBorder.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCategory(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        15.h,
        Column(
          spacing: 20.0,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String label,
    Color? labelColor,
    required IconData icon,
    Color? iconColor,
    required Widget child,
    Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconBtn(
                icon: icon,
                iconSize: 25.0,
                iconColor: iconColor ?? context.adaptiveTextSecondary,
                padding: 12.0,
                backgroundColor: context.adaptiveBorder.withValues(alpha: 0.07),
              ),
              15.w,
              Text(
                label,
                style: context.bodySmall?.copyWith(
                  fontSize: 18,
                  color: labelColor ?? context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildHeaderAccount({
    required BuildContext ctx,
    required Profile user,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: user.avatarUrl != null
          ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.avatarUrl!,
              fit: BoxFit.cover,
              errorListener: (value) {
                LogConfig.logError('❌ Erreur chargement image: $value');
                // Marquer l'erreur et afficher le fallback
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _hasImageError = true;
                      _isImageLoading = false;
                    });
                  }
                });
              },
            ),
          )
          : Center(
            child: Text(
              user.initials,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: darken(color),
              ),
            ),
          ),
        ),
    
        10.h,
    
        Column(
          children: [
            Text(
              user.fullName ?? context.l10n.defaultUserName,
              style: ctx.bodyMedium?.copyWith(
                fontSize: 22,
                color: context.adaptiveTextPrimary,
              ),
            ),
            Text(
              "@${user.username}",
              style: GoogleFonts.inter(
                fontSize: 17,
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _navigateToCredits() {
    _trackAccountAction('manage_credits_clicked');
    showModalSheet(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      child: CreditPlansScreen(),
    );
    // context.push('/manage-credits');
  }

  void _navigateToEditTheme() {
    _trackAccountAction('edit_theme_clicked');

    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      context: context,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      constraints: BoxConstraints(
        maxWidth: double.infinity, // ✅ Force la largeur maximale
      ),
      builder: (context) => ThemeSelector(),
    );
  }

  void _navigateToEditLanguage() {
    _trackAccountAction('edit_language_clicked');

    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      context: context,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      constraints: BoxConstraints(
        maxWidth: double.infinity, // ✅ Force la largeur maximale
      ),
      builder: (context) => LanguageSelector(),
    );
  }

  void _navigateToEditProfile(BuildContext context, Profile profile) {
    _trackAccountAction('edit_profile_clicked');

    // 🆕 Activer le chargement avant d'ouvrir EditProfileScreen
    setState(() {
      _isProfileUpdating = true;
    });

    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      context: context,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      constraints: BoxConstraints(
        maxWidth: double.infinity, // ✅ Force la largeur maximale
      ),
      builder: (context) => EditProfileScreen(
        profile: profile,
      ),
    ).then((_) {
      // 🆕 Désactiver le chargement si la modal se ferme sans mise à jour
      if (_isProfileUpdating) {
        setState(() {
          _isProfileUpdating = false;
        });
      }
    });

    HapticFeedback.lightImpact();
  }

  void _showLogoutDialog(BuildContext context) {
    _trackAccountAction('logout_dialog_opened');

    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: context.l10n.logoutTitle,
        subtitle: context.l10n.logoutMessage,
        validLabel: context.l10n.logoutConfirm,
        onValid: () {
          HapticFeedback.mediumImpact();

          // Fermer immédiatement la modal de confirmation
          context.pop();

          // Fermer immédiatement la modal AccountScreen
          if (context.mounted && Navigator.canPop(context)) {
            context.pop();
          }

          // Marquer qu'on est en train de se déconnecter
          setState(() {
            _isLoggingOut = true;
          });

          // Déclencher la déconnexion
          context.authBloc.add(LogOutRequested());
        },
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    // Vérifier la connexion avant la connexion Apple
    if (!ConnectivityHelper.checkConnectionAndShowModal(context)) {
      return;
    }
    
    _trackAccountAction('delete_account_dialog_opened');
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        isDestructive: true,
        activeCancel: false,
        title: context.l10n.deleteAccountTitle,
        subtitle: context.l10n.deleteAccountMessage,
        validLabel: context.l10n.delete,
        onValid: () {
          HapticFeedback.mediumImpact();

          // Fermer immédiatement la modal de confirmation
          context.pop();

          // Fermer immédiatement la modal AccountScreen
          if (context.mounted && Navigator.canPop(context)) {
            context.pop();
          }

          // Marquer qu'on est en train de supprimer le compte
          setState(() {
            _isDeletingAccount = true;
          });

          // Déclencher la suppression du compte
          context.authBloc.add(DeleteAccountRequested());
        },
      ),
    );
  }
}
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_event.dart';
import 'package:runaway/core/blocs/notification/notification_state.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/blurry_app_bar.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/account/presentation/widgets/language_selector.dart';
import 'package:runaway/features/account/presentation/widgets/theme_selector.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:math' as math;

import 'package:url_launcher/url_launcher.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isProfileUpdating = false; // 🆕 Flag pour éviter le modal pendant la mise à jour
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
      throw Exception('Could not launch $url');
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
            title: 'Could not launch email app',
            icon: HugeIcons.solidRoundedCancelCircle,
            color: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // 🆕 Détecter les transitions de mise à jour de profil
        if (previous is Authenticated && current is Authenticated) {
          _isProfileUpdating = true;
          // Réinitialiser le flag après un délai
          Future.delayed(Duration(seconds: 3), () {
            _isProfileUpdating = false;
          });
        }
        
        return previous.runtimeType != current.runtimeType;
      },
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          // 🆕 Vérifier qu'on n'est pas en train de mettre à jour
          if (!_isProfileUpdating) {
            showAuthModal(context);
          }
        } else if (authState is AuthError) {
          // Afficher l'erreur de suppression de compte
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${authState.message}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {          
          // Si l'utilisateur est connecté, afficher le contenu
          if (authState is Authenticated) {
            return _buildAuthenticatedView(authState);
          }

          return _buildEmptyUnauthenticated();
        },
      ),
    );
  }

  Widget _buildEmptyUnauthenticated() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            context.l10n.account,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
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
      ),
    );
  }

  Widget _buildAuthenticatedView(Authenticated authState) {
    final user = authState.profile;
    final initialColor = math.Random().nextInt(Colors.primaries.length);

    return BlurryAppBar(
      title: context.l10n.account, 
      children: [
        _buildHeaderAccount(
          ctx: context,
          user: user,
          color: Colors.primaries[initialColor],
        ),
    
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
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
                    onTap:
                        () => showModalSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          child: LanguageSelector(),
                        ),
                    child: IconBtn(
                      padding: 0.0,
                      backgroundColor: Colors.transparent,
                      label: context.l10n.currentLanguage,
                      iconSize: 19,
                      labelColor: context.adaptiveTextSecondary,
                      iconColor: context.adaptiveTextSecondary,
                      trailling: HugeIcons.strokeStandardArrowRight01,
                    ),
                  ),
    
                  // Notification switch
                  _buildSettingTile(
                    context,
                    label: context.l10n.notifications,
                    icon: HugeIcons.strokeRoundedNotification02,
                    child: BlocBuilder<NotificationBloc, NotificationState>(
                      builder: (context, notificationState) {
                        // Afficher un indicateur de chargement si en cours d'initialisation
                        if (notificationState.isLoading &&
                            !notificationState.isInitialized) {
                          return SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.adaptivePrimary,
                              ),
                            ),
                          );
                        }
    
                        return Switch(
                          value: notificationState.notificationsEnabled,
                          inactiveThumbColor: context.adaptiveDisabled,
                          activeColor: context.adaptivePrimary,
                          onChanged:
                              notificationState.isLoading
                                  ? null
                                  : (value) {
                                    HapticFeedback.mediumImpact();
    
                                    // Déclencher l'événement pour basculer les notifications
                                    context.notificationBloc.add(
                                      NotificationToggleRequested(
                                        enabled: value,
                                      ),
                                    );
                                  },
                        );
                      },
                    ),
                  ),
    
                  // Theme selector
                  _buildSettingTile(
                    context,
                    label: context.l10n.theme,
                    icon: HugeIcons.strokeRoundedPaintBoard,
                    onTap:
                        () => showModalSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          child: const ThemeSelector(),
                        ),
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
    
              80.h,
    
              _buildAppVersion(),
    
              80.h,
            ],
          ),
        ),
      ],
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
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () => print('Open Terms & Policy'),
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
          style: context.bodyMedium?.copyWith(
            fontSize: 18,
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w600,
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

  void _openAvatar(BuildContext context, Profile user) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),

        pageBuilder: (_, Animation<double> animation, __) {
          return _AvatarViewer(
            url: user.avatarUrl!,
            animation: animation,
            onTap: () {
              context.pop();
              _navigateToEditProfile(context, user);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderAccount({
    required BuildContext ctx,
    required Profile user,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: HSLColor.fromColor(color).withLightness(0.8).toColor(),
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
            child:
                user.avatarUrl != null
                    ? GestureDetector(
                      onTap: () {
                        // Show pop-up dialog
                        _openAvatar(context, user);
                      },
                      child: Hero(
                        tag: user.avatarUrl!,

                        // ✅ 1. garder la forme ronde pendant l’attente
                        placeholderBuilder:
                            (_, __, child) => ClipOval(child: child),

                        // ✅ 2. forcer aussi le shuttle à rester rond (push & pop)
                        flightShuttleBuilder: (
                          context,
                          animation,
                          direction,
                          fromCtx,
                          toCtx,
                        ) {
                          final shuttle =
                              direction == HeroFlightDirection.push
                                  ? toCtx
                                      .widget // agrandissement
                                  : fromCtx.widget; // réduction
                          return ClipOval(child: shuttle);
                        },

                        child: ClipOval(
                          // <-- ou CircleAvatar, comme vous préférez
                          child: CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                    : Center(
                      child: Text(
                        user.initials,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: color,
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
                style: ctx.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),

          20.h,

          IconBtn(
            padding: 10,
            trailling: HugeIcons.strokeStandardArrowRight01,
            iconSize: 20,
            label: context.l10n.editProfile,
            textStyle: ctx.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            iconColor: Colors.white,
            backgroundColor: context.adaptivePrimary,
            onPressed:
                () => _navigateToEditProfile(context, user), // Nouvelle méthode
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context, Profile profile) {
    context.push('/edit-profile', extra: profile);
  }

  void _showLogoutDialog(BuildContext context) {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: context.l10n.logoutTitle,
        subtitle: context.l10n.logoutMessage,
        validLabel: context.l10n.logoutConfirm,
        onValid: () {
          HapticFeedback.mediumImpact();

          context.pop();

          context.authBloc.add(LogOutRequested());
        },
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
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

          context.pop();

          context.authBloc.add(DeleteAccountRequested());
        },
      ),
    );
  }
}

class _AvatarViewer extends StatelessWidget {
  final String url;
  final Animation<double> animation;
  final VoidCallback? onTap;

  const _AvatarViewer({
    required this.url,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // sigma passe de 0 à 30
        final sigma = 30 * animation.value;
        // opacité du voile passe de 0 à 0.25
        final veilOpacity = 0.25 * animation.value;

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // fond flouté / assombri
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // capte toute la surface
                  onTap: () => Navigator.of(context).pop(),
                  child: FadeTransition(
                    opacity: animation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: Container(
                        color: context.adaptiveBackground.withValues(
                          alpha: veilOpacity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // l’image agrandie (la destination du Hero)
              Center(
                child: SizedBox(
                  height: 280,
                  width: 280,
                  child: Hero(
                    tag: url, // même tag que la vignette
                    flightShuttleBuilder: _buildShuttle, // rendu custom
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              // Positioned(
              //   bottom: 50,
              //   child: FadeTransition(
              //     opacity: animation,
              //     child: IconBtn(
              //       onPressed: onTap,
              //       label: context.l10n.editPhoto,
              //       icon: HugeIcons.strokeRoundedImage02,
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }

  // Personnaliser le rendu pendant le vol
  Widget _buildShuttle(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHero,
    BuildContext toHero,
  ) {
    return FadeTransition(opacity: animation, child: toHero.widget);
  }
}

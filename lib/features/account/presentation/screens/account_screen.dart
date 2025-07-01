import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/features/account/presentation/widgets/language_selector.dart';
import 'package:runaway/features/account/presentation/widgets/theme_selector.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'dart:math' as math;


class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;

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


    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          // L'utilisateur s'est déconnecté, rediriger vers l'accueil
          context.go('/home');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {
          // Si l'utilisateur est connecté, afficher le contenu
          if (authState is Authenticated) {
            return _buildAuthenticatedView(authState);
          }

          return AskRegistration();
        }
      ),
    );
  }

  Widget _buildAuthenticatedView(Authenticated authState) {
    final user = authState.profile;
    final initialColor = math.Random().nextInt(Colors.primaries.length);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        title: Text(
          context.l10n.account,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      body: BlurryPage(
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
                _buildSettingCategory(
                  context,
                  title: context.l10n.preferences,
                  children: [
                    _buildSettingTile(
                      context,
                      label: context.l10n.language,
                      icon: HugeIcons.strokeRoundedLanguageSkill,
                      onTap: () => showModalSheet(
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
                    _buildSettingTile(
                      context,
                      label: context.l10n.notifications,
                      icon: HugeIcons.strokeRoundedNotification02,
                      onTap: () {}, 
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        label: context.l10n.enabled,
                        iconSize: 19,
                        labelColor: context.adaptiveTextSecondary,
                        iconColor: context.adaptiveTextSecondary,
                        trailling: HugeIcons.strokeStandardArrowRight01,
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      label: context.l10n.theme,
                      icon: HugeIcons.strokeRoundedPaintBoard,
                      onTap: () => showModalSheet(
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
                        }
                      ),
                    ),
                  ]
                ),
        
                // _buildSettingCategory(
                //   context,
                //   title: "Notifications",
                //   children: [
                //     _buildSettingTile(
                //       context,
                //       label: "Push notifications",
                //       icon: HugeIcons.strokeRoundedNotificationSquare,
                //       child: Switch(
                //         value: true, 
                //         onChanged: (value) {
                //           // TODO: Implémenter la gestion des notifications push
                //         },
                //       )
                //     ),
                //     20.h,
                //     _buildSettingTile(
                //       context,
                //       label: "Email notifications",
                //       icon: HugeIcons.strokeRoundedMail01,
                //       child: Switch(
                //         value: true,
                //         padding: EdgeInsets.zero, 
                //         onChanged: (value) {
                //           // TODO: Implémenter la gestion des notifications email
                //         },
                //       )
                //     ),
                //   ]
                // ),
    
                50.h,
    
                _buildSettingCategory(
                  context,
                  title: context.l10n.account,
                  children: [
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
                  ]
                ),
    
                80.h,
              ],
            ),
          )
        ],
      )
    );
  }

  Widget _buildSettingCategory(BuildContext context, {required String title, required List<Widget> children}) {
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
        )
      ],
    );
  }

  Widget _buildSettingTile(BuildContext context, {required String label, Color? labelColor, required IconData icon, Color? iconColor, required Widget child, required Function()? onTap}) {
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
              Text(label, style: context.bodySmall?.copyWith(color: labelColor ?? context.adaptiveTextPrimary)),
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
              ]
            ),
            child: user.avatarUrl != null
                ? GestureDetector(
                  onTap: () {
                    // Show pop-up dialog
                    _openAvatar(context, user);
                  },
                  child: Hero(
                    tag: user.avatarUrl!,
                  
                    // ✅ 1. garder la forme ronde pendant l’attente
                    placeholderBuilder: (_, __, child) => ClipOval(child: child),
                  
                    // ✅ 2. forcer aussi le shuttle à rester rond (push & pop)
                    flightShuttleBuilder: (context, animation, direction, fromCtx, toCtx) {
                      final shuttle = direction == HeroFlightDirection.push
                          ? toCtx.widget   // agrandissement
                          : fromCtx.widget; // réduction
                      return ClipOval(child: shuttle);
                    },
                  
                    child: ClipOval(          // <-- ou CircleAvatar, comme vous préférez
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
            onPressed: () => _navigateToEditProfile(context, user), // Nouvelle méthode 
          )
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context, Profile profile) {
    context.push('/edit-profile', extra: profile);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          context.l10n.logoutTitle,
          style: context.titleMedium?.copyWith(color: Colors.white),
        ),
        content: Text(
          context.l10n.logoutMessage,
          style: context.bodyMedium?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.l10n.cancel, 
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(LogOutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(context.l10n.logoutConfirm),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          context.l10n.deleteAccountTitle,
          style: context.titleMedium?.copyWith(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.deleteAccountMessage,
              style: context.bodyMedium?.copyWith(color: Colors.white70),
            ),
            16.h,
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: Colors.red,
                    size: 16,
                  ),
                  8.w,
                  Expanded(
                    child: Text(
                      context.l10n.deleteAccountWarning,
                      style: context.bodySmall?.copyWith(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.l10n.cancel, 
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // TODO: Implémenter la suppression du compte
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.deleteAccountTodo),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _AvatarViewer extends StatelessWidget {
  final String url;
  final Animation<double> animation;
  final VoidCallback? onTap;

  const _AvatarViewer({required this.url, required this.animation, required this.onTap});

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
                  behavior: HitTestBehavior.opaque,     // capte toute la surface
                  onTap: () => Navigator.of(context).pop(),
                  child: FadeTransition(
                    opacity: animation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: Container(color: context.adaptiveBackground.withValues(alpha: veilOpacity)),
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
        
              Positioned(
                bottom: 50,
                child: FadeTransition(
                  opacity: animation,
                  child: IconBtn(
                    onPressed: onTap,
                    label: context.l10n.editPhoto,
                    icon: HugeIcons.strokeRoundedImage02,
                  ),
                ),
              )
            ],
          ),
        );
      }
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
  

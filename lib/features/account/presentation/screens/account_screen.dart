import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
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

  // Dans la classe _AccountScreenState, ajouter cette méthode :
  Future<void> _pickAndUpdateAvatar(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (pickedFile != null && context.mounted) {
        final File avatarFile = File(pickedFile.path);
        
        // Déclencher la mise à jour du profil avec la nouvelle photo
        context.read<AuthBloc>().add(
          UpdateProfileRequested(avatar: avatarFile),
        );
                
        // Afficher un message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mise à jour de la photo en cours...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
        print(e.toString());
      }
    }
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
          "Account",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: BlurryPage(
        children: [
          _buildHeaderAccount(
            ctx: context,
            name: user.fullName ?? "Utilisateur",
            username: "@${user.username}",
            avatarUrl: user.avatarUrl,
            initials: user.initials,
            color: Colors.primaries[initialColor],
          ),
    
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildSettingCategory(
                  context,
                  title: "Preferences",
                  children: [
                    _buildSettingTile(
                      context,
                      label: "Language",
                      icon: HugeIcons.strokeRoundedLanguageSkill,
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        label: "English",
                        onPressed: () {}, 
                        iconSize: 19,
                        labelColor: Colors.white54,
                        iconColor: Colors.white54,
                        trailling: HugeIcons.strokeStandardArrowRight01,
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      label: "Notifications",
                      icon: HugeIcons.strokeRoundedNotification02,
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        label: "Enabled",
                        onPressed: () {}, 
                        iconSize: 19,
                        labelColor: Colors.white54,
                        iconColor: Colors.white54,
                        trailling: HugeIcons.strokeStandardArrowRight01,
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      label: "Theme",
                      icon: HugeIcons.strokeRoundedPaintBoard,
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        label: "Light",
                        onPressed: () {}, 
                        iconSize: 19,
                        labelColor: Colors.white54,
                        iconColor: Colors.white54,
                        trailling: HugeIcons.strokeStandardArrowRight01,
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
                  title: "Account",
                  children: [
                    _buildSettingTile(
                      context,
                      label: "Disconnect",
                      icon: HugeIcons.strokeRoundedLogoutSquare02,
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        onPressed: () => _showLogoutDialog(context), 
                        iconSize: 19,
                        iconColor: Colors.white54,
                        trailling: HugeIcons.strokeStandardArrowRight01,
                      ),
                    ),
                    _buildSettingTile(
                      context,
                      label: "Delete profile",
                      icon: HugeIcons.strokeRoundedDelete02,
                      iconColor: Colors.red,
                      labelColor: Colors.red,
                      child: IconBtn(
                        padding: 0.0,
                        backgroundColor: Colors.transparent,
                        onPressed: () => _showDeleteAccountDialog(context), 
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
            color: Colors.white54, 
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

  Widget _buildSettingTile(BuildContext context, {required String label, Color labelColor = Colors.white, required IconData icon, Color iconColor = Colors.white, required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconBtn(
              icon: icon,
              iconSize: 25.0, 
              iconColor: iconColor,
              padding: 12.0,
              backgroundColor: Colors.white10,
            ),
            15.w,
            Text(label, style: context.bodySmall?.copyWith(color: labelColor)),
          ],
        ),
        child,
      ],
    );
  }

  void _openAvatar(BuildContext context, String url) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,                    // on veut voir la page dessous
        barrierColor: Colors.transparent, // pas de flash noir
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),

        // ─── le « child » reçoit l'animation ───
        pageBuilder: (_, Animation<double> animation, __) {
          return _AvatarViewer(
            url: url, 
            animation: animation, 
            onTap: () => _pickAndUpdateAvatar(context),
          );
        },
      ),
    );
  }

  Widget _buildHeaderAccount({
    required BuildContext ctx, 
    required String name, 
    required String username,
    String? avatarUrl,
    required String initials,
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
            ),
            child: avatarUrl != null
                ? GestureDetector(
                  onTap: () {
                    // Show pop-up dialog
                    _openAvatar(context, avatarUrl);
                  },
                  child: Hero(
                    tag: avatarUrl,
                  
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
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
                : Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
          ),

          8.h,

          Column(
            children: [
              Text(
                name,
                style: ctx.bodyMedium?.copyWith(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
              Text(
                username,
                style: ctx.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white38,
                ),
              ),
            ],
          ),

          20.h,

          IconBtn(
            padding: 10,
            trailling: HugeIcons.strokeStandardArrowRight01,
            iconSize: 19,
            label: "Edit profile",
            textStyle: ctx.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            backgroundColor: AppColors.primary,
            onPressed: () {
              // TODO: Naviguer vers l'écran d'édition de profil
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Édition du profil - À implémenter'),
                  backgroundColor: Colors.orange,
                ),
              );
            }, 
          )
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Déconnexion',
          style: context.titleMedium?.copyWith(color: Colors.white),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: context.bodyMedium?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Annuler', 
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
            child: Text('Déconnexion'),
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
          'Supprimer le compte',
          style: context.titleMedium?.copyWith(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
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
                      'Cette action ne peut pas être annulée',
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
              'Annuler', 
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // TODO: Implémenter la suppression du compte
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Suppression du compte - À implémenter'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Supprimer'),
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
                      child: Container(color: Colors.white.withValues(alpha: veilOpacity)),
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
                    label: "Edit the photo",
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
  

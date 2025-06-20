import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import 'dart:math' as math;

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
            final user = authState.profile;
            final initialColor = math.Random().nextInt(Colors.primaries.length);

            return Scaffold(
              extendBodyBehindAppBar: true,
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
                          title: "Dashboard",
                          children: [
                            _buildSettingTile(
                              context,
                              label: "Insurance",
                              icon: HugeIcons.strokeRoundedAirdrop,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {}, 
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            20.h,
                            _buildSettingTile(
                              context,
                              label: "Cryptocurency",
                              icon: HugeIcons.strokeRoundedAirdrop,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {}, 
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            20.h,
                            _buildSettingTile(
                              context,
                              label: "Trading",
                              icon: HugeIcons.strokeRoundedAirdrop,
                              child: IconButton(
                                onPressed: () {}, 
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ]
                        ),
            
                        50.h,
            
                        _buildSettingCategory(
                          context,
                          title: "Notifications",
                          children: [
                            _buildSettingTile(
                              context,
                              label: "Push notifications",
                              icon: HugeIcons.strokeRoundedNotificationSquare,
                              child: Switch(
                                value: true, 
                                onChanged: (value) {
                                  // TODO: Implémenter la gestion des notifications push
                                },
                              )
                            ),
                            20.h,
                            _buildSettingTile(
                              context,
                              label: "Email notifications",
                              icon: HugeIcons.strokeRoundedMail01,
                              child: Switch(
                                value: true,
                                padding: EdgeInsets.zero, 
                                onChanged: (value) {
                                  // TODO: Implémenter la gestion des notifications email
                                },
                              )
                            ),
                          ]
                        ),

                        50.h,
            
                        _buildSettingCategory(
                          context,
                          title: "Account",
                          children: [
                            _buildSettingTile(
                              context,
                              label: "Edit Profile",
                              icon: HugeIcons.strokeRoundedUserEdit01,
                              child: IconButton(
                                onPressed: () {
                                  // TODO: Naviguer vers l'écran d'édition de profil
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Édition du profil - À implémenter'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }, 
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            20.h,
                            _buildSettingTile(
                              context,
                              label: "Disconnect",
                              icon: HugeIcons.strokeRoundedLogoutSquare02,
                              child: IconButton(
                                onPressed: () => _showLogoutDialog(context), 
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            20.h,
                            _buildSettingTile(
                              context,
                              label: "Delete Account",
                              icon: HugeIcons.strokeRoundedDelete02,
                              iconColor: Colors.red,
                              labelColor: Colors.red,
                              child: IconButton(
                                onPressed: () => _showDeleteAccountDialog(context), 
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  HugeIcons.strokeStandardArrowRight01, 
                                  color: Colors.white38,
                                ),
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

          return AskRegistration();
        }
      ),
    );
  }

  Widget _buildSettingCategory(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        15.h,
        Column(
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
            Icon(icon, color: iconColor),
            15.w,
            Text(label, style: context.bodySmall?.copyWith(color: labelColor)),
          ],
        ),
        child,
      ],
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
              image: avatarUrl != null 
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                      onError: (error, stackTrace) {
                        // En cas d'erreur de chargement de l'image
                        print('Erreur chargement avatar: $error');
                      },
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  )
                : null,
          ),

          20.h,
          Text(
            name,
            style: ctx.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
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


class BlurryPage extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;
  final Color? color;
  
  const BlurryPage({super.key, required this.children, this.padding, this.contentPadding, this.color});

  @override
  State<BlurryPage> createState() => _BlurryPageState();
}

class _BlurryPageState extends State<BlurryPage> {
  late final ScrollController _scrollController;
  bool _isCutByTop = false; // au lancement, le début est sous la modal

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
    ..addListener(() {
      final cut = _scrollController.offset > 0;
      if (cut != _isCutByTop) {
        setState(() => _isCutByTop = cut);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProgressiveBlurWidget(
          sigma: _isCutByTop ? 100.0 : 0,
          linearGradientBlur: const LinearGradientBlur(
            values: [1, 0], // 0 - no blur, 1 - full blur
            stops: [0.0, 0.4],
            start: Alignment.topCenter,
            end: Alignment.center,
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ProgressiveBlurWidget(
                sigma: 50.0,
                linearGradientBlur: const LinearGradientBlur(
                  values: [0, 1], // 0 - no blur, 1 - full blur
                  stops: [0.5, 0.9],
                  start: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
                child: Padding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  child: ListView(
                    padding: widget.contentPadding,
                    controller: _scrollController,
                    children: widget.children
                  ),
                ),
              ),
            
              IgnorePointer(
                ignoring: true,
                child: Container(
                  height: MediaQuery.of(context).size.height / 3,
                  decoration: BoxDecoration(
                    gradient: SmoothGradient(
                      from: widget.color?.withValues(alpha: 0) ?? AppColorsDark.background.withValues(alpha: 0),
                      to: widget.color ?? AppColorsDark.background,
                      curve: Curves.linear,
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: _isCutByTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: MediaQuery.of(context).size.height / 3,
                decoration: BoxDecoration(
                  gradient: SmoothGradient(
                    from: widget.color ?? AppColorsDark.background,
                    to: widget.color?.withValues(alpha: 0) ?? AppColorsDark.background.withValues(alpha: 0),
                    curve: Curves.linear,
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
        ),
      ],
    );
  }
}
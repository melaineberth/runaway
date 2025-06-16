import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (_, authState) {
        if (authState is !Authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModalBottomSheet(
              context: context, 
              useRootNavigator: true,
              enableDrag: false,
              isDismissible: false,
              isScrollControlled: true,
              builder: (modalCtx) {
                return AskRegistration();
              },
            );
          });
        } 

        if (authState is Authenticated) {
          final user = authState.profile;

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
                  name: "Richard",
                  username: "@${user.username}"
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
                            child: Switch(value: true, onChanged: (value) {})
                          ),
                          20.h,
                          _buildSettingTile(
                            context,
                            label: "Email notifications",
                            icon: HugeIcons.strokeRoundedMail01,
                            child: Switch(
                              value: true,
                              padding: EdgeInsets.zero, 
                              onChanged: (value) {},
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
                            label: "Disconnect",
                            icon: HugeIcons.strokeRoundedLogoutSquare02,
                            child: IconButton(
                              onPressed: () {}, 
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                HugeIcons.strokeStandardArrowRight01, 
                                color: Colors.white38,
                              ),
                            ),
                          ),
                          _buildSettingTile(
                            context,
                            label: "Delete",
                            icon: HugeIcons.strokeRoundedDelete02,
                            iconColor: Colors.red,
                            labelColor: Colors.red,
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
          
                      80.h,
                    ],
                  ),
                )
              ],
            )
          );
        }

        return SizedBox.shrink();
      }
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

  Widget _buildHeaderAccount({required BuildContext ctx, required String name, required String username}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 20.0,
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage("https://picsum.photos/200"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          15.h,
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
}

class BlurryPage extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  
  const BlurryPage({super.key, required this.children, this.padding});

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
                      from: AppColorsDark.background.withValues(alpha: 0),
                      to: AppColorsDark.background,
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
                    from: AppColorsDark.background,
                    to: AppColorsDark.background.withValues(alpha: 0),
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
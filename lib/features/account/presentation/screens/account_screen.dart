import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

import '../../../../core/widgets/ask_registration.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool isAuth = false;

  @override
  void initState() {
    checkAuth();
    super.initState();
  }

  void checkAuth() {
    if (!isAuth) {
      _showAuthModal();
    }
  }

  Future<void> _showAuthModal() async { 
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

  @override
  Widget build(BuildContext context) {
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
      body: isAuth 
      ? BlurryPage(
        children: [
          _buildHeaderAccount(context),
      
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

                80.h,
              ],
            ),
          )
        ],
      )
      : null,
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

  Widget _buildSettingTile(BuildContext context, {required String label, required IconData icon, required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white),
            15.w,
            Text(label, style: context.bodySmall?.copyWith(color: Colors.white)),
          ],
        ),
        child,
      ],
    );
  }

  Widget _buildHeaderAccount(BuildContext context) {
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
            "Richard Jeromy",
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            "@richajex01",
            style: context.bodySmall?.copyWith(
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
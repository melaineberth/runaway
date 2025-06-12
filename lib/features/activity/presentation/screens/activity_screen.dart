import 'package:flutter/material.dart';

import '../../../../core/widgets/ask_registration.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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
    return const Placeholder();
  }
}
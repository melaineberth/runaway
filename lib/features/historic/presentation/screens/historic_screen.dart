import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';

import '../../../../core/widgets/ask_registration.dart';
import '../widgets/historic_card.dart';

class HistoricScreen extends StatefulWidget {
  const HistoricScreen({super.key});

  @override
  State<HistoricScreen> createState() => _HistoricScreenState();
}

class _HistoricScreenState extends State<HistoricScreen> {
  bool isAuth = true;

  final List<HistoricCard> data = [
    HistoricCard(
      imgPath: "assets/img/road.png",
      title: "Parcours d'entraînement",
      location: "Brulon, France",
      timestamp: "le 10/10/25 à 12h00",
    ),
  ];

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
          "Historique",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: data.length > 1 ? BlurryPage(
        padding: EdgeInsets.all(20.0),
        children: List.generate(
          data.length, 
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index >= data.length ? 0 : 15.0),
            child: data[index],
          ),
        ),
      ) : null,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';

/// Card pour afficher un plan de crédits
class CreditPlanCard extends StatelessWidget {
  final CreditPlan plan;
  final VoidCallback onTap;
  final bool isSelected;
  final ProductDetails? productDetails; // 🆕 Ajout ProductDetails optionnel

  const CreditPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.isSelected = false,
    this.productDetails, // 🆕 Paramètre optionnel
  });

  /// 🆕 Récupère le prix formaté (store en priorité)
  String get displayPrice {
    if (productDetails != null) {
      // Construire le prix avec rawPrice + symbole converti
      return '${productDetails!.rawPrice.toStringAsFixed(2)}$displayCurrencySymbol';
    }
    // Pour le fallback, convertir aussi le code de devise du plan
    final symbol = _currencyCodeToSymbol(plan.currency);
    return '${plan.price.toStringAsFixed(2)}$symbol';
  }

  /// 🆕 Récupère le nom localisé en fonction de la langue
  String _getLocalizedName(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    
    // Mapping des noms par plan et langue
    switch (plan.iapId) {
      case 'com.trailix.credits.starter.test': // ID du plan Découverte
        switch (locale) {
          case 'en': return 'Discovery';
          case 'fr': return 'Découverte';
          case 'es': return 'Descubrimiento';
          case 'de': return 'Entdeckung';
          default: return 'Discovery';
        }
      case 'com.trailix.credits.popular.test': // ID du plan Nomade
        switch (locale) {
          case 'en': return 'Nomad';
          case 'fr': return 'Nomade';
          case 'es': return 'Nómada';
          case 'de': return 'Nomade';
          default: return 'Nomad';
        }
      case 'com.trailix.credits.premium.test': // ID du plan Baroudeur
        switch (locale) {
          case 'en': return 'Adventurer';
          case 'fr': return 'Baroudeur';
          case 'es': return 'Aventurero';
          case 'de': return 'Abenteurer';
          default: return 'Adventurer';
        }
      case 'com.trailix.credits.ultimate.test': // ID du plan Explorateur
        switch (locale) {
          case 'en': return 'Explorer';
          case 'fr': return 'Explorateur';
          case 'es': return 'Explorador';
          case 'de': return 'Entdecker';
          default: return 'Explorer';
        }
      default:
        // Fallback sur ProductDetails ou plan.name
        return productDetails?.title ?? plan.name;
    }
  }

  /// 🆕 Récupère le nom à afficher (localisé en priorité)
  String getDisplayName(BuildContext context) {
    return _getLocalizedName(context);
  }

  /// 🆕 Convertit le code de devise en symbole
  String _currencyCodeToSymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'CAD':
        return '\$';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CHF':
        return 'CHF';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'KRW':
        return '₩';
      case 'SEK':
        return 'kr';
      case 'NOK':
        return 'kr';
      case 'DKK':
        return 'kr';
      case 'PLN':
        return 'zł';
      case 'CZK':
        return 'Kč';
      case 'HUF':
        return 'Ft';
      case 'RUB':
        return '₽';
      case 'TRY':
        return '₺';
      case 'ZAR':
        return 'R';
      case 'THB':
        return '฿';
      case 'MYR':
        return 'RM';
      case 'PHP':
        return '₱';
      case 'IDR':
        return 'Rp';
      case 'VND':
        return '₫';
      default:
       return "€";
  }}

  /// 🆕 Récupère le symbole de la currency (store en priorité)
  String get displayCurrencySymbol {
    if (productDetails != null) {
      // Essayer d'abord le currencySymbol du store
      final storeSymbol = productDetails!.currencySymbol;
      if (storeSymbol.isNotEmpty && storeSymbol != productDetails!.currencyCode) {
        return storeSymbol;
      }
      // Sinon convertir le code en symbole
      return _currencyCodeToSymbol(productDetails!.currencyCode);
    }
    return _currencyCodeToSymbol(plan.currency);
  }

  /// 🆕 Calcule le prix par crédit avec les données du store
  double get pricePerCredit {
    if (productDetails != null) {
      // Extraire le prix numérique du string formaté du store
      final priceString = productDetails!.rawPrice.toString();
      final numericPrice = double.tryParse(priceString) ?? productDetails!.rawPrice;
      return numericPrice / plan.credits;
    }
    return plan.pricePerCredit;
  }


  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      gradient: false,
      color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                getDisplayName(context), // 🆕 Utilisation du nom localisé
                style: context.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : context.adaptiveDisabled,
                  fontSize: 17,
                ),
              ),
              
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(
                    '${plan.totalCreditsWithBonus} crédits',
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : context.adaptiveTextPrimary,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayPrice,
                    style: context.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : context.adaptiveTextPrimary,
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    '(${(plan.pricePerCredit).toStringAsFixed(2)}$displayCurrencySymbol/crédit)',
                    style: context.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : context.adaptiveTextSecondary,
                      fontSize: 14,
                    ),
                  ),  
                ],
              ),
            ],
          ),      
        ],
      ),
    );
  }
}
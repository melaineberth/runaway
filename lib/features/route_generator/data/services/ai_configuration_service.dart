import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service de configuration pour le système IA
class AIConfigurationService {
  
  // Configuration des modèles IA
  static const Map<String, AIModelConfig> availableModels = {
    'llama-3.1-70b-versatile': AIModelConfig(
      name: 'Llama 3.1 70B Versatile',
      description: 'Modèle le plus intelligent, recommandé pour les parcours complexes',
      maxTokens: 4000,
      temperature: 0.2,
      costLevel: AICostLevel.high,
      capabilities: [
        AICapability.complexRouting,
        AICapability.advancedAnalysis,
        AICapability.multiCriteria,
      ],
    ),
    'llama-3.1-8b-instant': AIModelConfig(
      name: 'Llama 3.1 8B Instant',
      description: 'Modèle rapide, adapté aux parcours simples',
      maxTokens: 3000,
      temperature: 0.3,
      costLevel: AICostLevel.low,
      capabilities: [
        AICapability.basicRouting,
        AICapability.fastGeneration,
      ],
    ),
    'mixtral-8x7b-32768': AIModelConfig(
      name: 'Mixtral 8x7B',
      description: 'Bon équilibre vitesse/qualité',
      maxTokens: 3500,
      temperature: 0.25,
      costLevel: AICostLevel.medium,
      capabilities: [
        AICapability.complexRouting,
        AICapability.multiCriteria,
      ],
    ),
  };

  /// Configuration par défaut selon le contexte
  static AIGenerationConfig getDefaultConfig({
    required double distanceKm,
    required String terrainType,
    required int networkSize,
  }) {
    // Choisir le modèle selon la complexité
    String selectedModel;
    
    if (distanceKm > 15 || networkSize > 3000 || terrainType == 'hilly') {
      selectedModel = 'llama-3.1-70b-versatile'; // Plus intelligent pour les cas complexes
    } else if (distanceKm < 5 && networkSize < 1000) {
      selectedModel = 'llama-3.1-8b-instant'; // Plus rapide pour les cas simples
    } else {
      selectedModel = 'mixtral-8x7b-32768'; // Équilibre par défaut
    }

    return AIGenerationConfig(
      model: selectedModel,
      maxRetries: 3,
      timeoutSeconds: 45,
      enableFallback: true,
      enableValidation: true,
      qualityThreshold: 0.7,
      distanceTolerance: 0.15, // 15% de tolérance sur la distance
    );
  }

  /// Configuration pour les tests/développement
  static AIGenerationConfig getDebugConfig() {
    return AIGenerationConfig(
      model: 'llama-3.1-8b-instant', // Modèle le moins cher
      maxRetries: 1,
      timeoutSeconds: 20,
      enableFallback: true,
      enableValidation: true,
      enableDebugLogging: true,
      qualityThreshold: 0.5, // Plus permissif
      distanceTolerance: 0.25,
    );
  }

  /// Configuration optimisée pour la production
  static AIGenerationConfig getProductionConfig({
    required double distanceKm,
    required String terrainType,
    required int networkSize,
  }) {
    final config = getDefaultConfig(
      distanceKm: distanceKm,
      terrainType: terrainType,
      networkSize: networkSize,
    );

    return config.copyWith(
      maxRetries: 2, // Moins de tentatives en prod
      timeoutSeconds: 30, // Timeout plus court
      enableDebugLogging: false,
      qualityThreshold: 0.8, // Plus strict
    );
  }

  /// Vérifie si l'IA est disponible et configurée
  static AIAvailabilityStatus checkAIAvailability() {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    
    if (apiKey.isEmpty) {
      return AIAvailabilityStatus(
        isAvailable: false,
        reason: 'GROQ_API_KEY manquant dans le fichier .env',
        recommendation: 'Ajoutez votre clé API GroqCloud dans le fichier .env',
      );
    }

    if (apiKey.length < 20) {
      return AIAvailabilityStatus(
        isAvailable: false,
        reason: 'Clé API invalide (trop courte)',
        recommendation: 'Vérifiez votre clé API GroqCloud',
      );
    }

    return AIAvailabilityStatus(
      isAvailable: true,
      reason: 'IA configurée et disponible',
    );
  }

  /// Estime le coût d'une génération
  static AICostEstimate estimateGenerationCost({
    required String model,
    required int networkSize,
    required int poisCount,
  }) {
    final modelConfig = availableModels[model];
    if (modelConfig == null) {
      return AICostEstimate(
        estimatedTokens: 0,
        costLevel: AICostLevel.unknown,
        description: 'Modèle inconnu',
      );
    }

    // Estimation des tokens basée sur la taille des données
    int estimatedTokens = 1000; // Base prompt
    estimatedTokens += (networkSize * 0.1).round(); // ~0.1 token par segment
    estimatedTokens += (poisCount * 10); // ~10 tokens par POI
    estimatedTokens += 500; // Réponse attendue

    // Limiter selon le modèle
    estimatedTokens = estimatedTokens.clamp(500, modelConfig.maxTokens);

    return AICostEstimate(
      estimatedTokens: estimatedTokens,
      costLevel: modelConfig.costLevel,
      description: _getCostDescription(modelConfig.costLevel, estimatedTokens),
    );
  }

  static String _getCostDescription(AICostLevel level, int tokens) {
    switch (level) {
      case AICostLevel.low:
        return 'Coût faible (~${(tokens / 1000).toStringAsFixed(1)}K tokens)';
      case AICostLevel.medium:
        return 'Coût modéré (~${(tokens / 1000).toStringAsFixed(1)}K tokens)';
      case AICostLevel.high:
        return 'Coût élevé (~${(tokens / 1000).toStringAsFixed(1)}K tokens)';
      case AICostLevel.unknown:
        return 'Coût inconnu';
    }
  }
}

/// Configuration d'un modèle IA
class AIModelConfig {
  final String name;
  final String description;
  final int maxTokens;
  final double temperature;
  final AICostLevel costLevel;
  final List<AICapability> capabilities;

  const AIModelConfig({
    required this.name,
    required this.description,
    required this.maxTokens,
    required this.temperature,
    required this.costLevel,
    required this.capabilities,
  });
}

/// Configuration de génération IA
class AIGenerationConfig {
  final String model;
  final int maxRetries;
  final int timeoutSeconds;
  final bool enableFallback;
  final bool enableValidation;
  final bool enableDebugLogging;
  final double qualityThreshold;
  final double distanceTolerance;

  const AIGenerationConfig({
    required this.model,
    this.maxRetries = 3,
    this.timeoutSeconds = 30,
    this.enableFallback = true,
    this.enableValidation = true,
    this.enableDebugLogging = false,
    this.qualityThreshold = 0.7,
    this.distanceTolerance = 0.15,
  });

  AIGenerationConfig copyWith({
    String? model,
    int? maxRetries,
    int? timeoutSeconds,
    bool? enableFallback,
    bool? enableValidation,
    bool? enableDebugLogging,
    double? qualityThreshold,
    double? distanceTolerance,
  }) {
    return AIGenerationConfig(
      model: model ?? this.model,
      maxRetries: maxRetries ?? this.maxRetries,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      enableFallback: enableFallback ?? this.enableFallback,
      enableValidation: enableValidation ?? this.enableValidation,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      qualityThreshold: qualityThreshold ?? this.qualityThreshold,
      distanceTolerance: distanceTolerance ?? this.distanceTolerance,
    );
  }
}

/// Status de disponibilité de l'IA
class AIAvailabilityStatus {
  final bool isAvailable;
  final String reason;
  final String? recommendation;

  const AIAvailabilityStatus({
    required this.isAvailable,
    required this.reason,
    this.recommendation,
  });
}

/// Estimation de coût
class AICostEstimate {
  final int estimatedTokens;
  final AICostLevel costLevel;
  final String description;

  const AICostEstimate({
    required this.estimatedTokens,
    required this.costLevel,
    required this.description,
  });
}

/// Niveaux de coût
enum AICostLevel {
  low,
  medium,
  high,
  unknown,
}

/// Capacités IA
enum AICapability {
  basicRouting,
  complexRouting,
  advancedAnalysis,
  multiCriteria,
  fastGeneration,
}
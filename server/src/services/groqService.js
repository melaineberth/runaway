const axios = require("axios");
const logger = require("../config/logger");

class GroqService {
  constructor() {
    this.apiKey = process.env.GROQ_API_KEY;
    this.model = process.env.GROQ_MODEL_ID || "llama-3.1-8b-instant";
    this.baseUrl = process.env.GROQ_CLOUD_URL;

    if (!this.apiKey) {
      logger.warn("GROQ_API_KEY not set, Groq features disabled");
    }
  }

  /**
   * Nettoie et valide la réponse JSON de Groq
   */
  _cleanAndParseJSON(text) {
    if (!text || typeof text !== 'string') {
      throw new Error('Response text is empty or invalid');
    }

    // Nettoyer le texte : supprimer les caractères de contrôle et espaces
    let cleanText = text.trim();
    
    // Supprimer les éventuels backticks de markdown
    cleanText = cleanText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    
    // Supprimer les caractères non-JSON au début/fin
    cleanText = cleanText.replace(/^[^[{]*/, '').replace(/[^}\]]*$/, '');
    
    if (!cleanText) {
      throw new Error('No valid JSON content found in response');
    }

    try {
      return JSON.parse(cleanText);
    } catch (parseError) {
      logger.warn('JSON parse failed, attempting to extract JSON from text', {
        originalText: text.substring(0, 100),
        cleanedText: cleanText.substring(0, 100),
        parseError: parseError.message
      });
      
      // Tentative d'extraction de JSON depuis le texte
      const jsonMatch = cleanText.match(/[\[{].*[\]}]/s);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[0]);
        } catch (secondError) {
          throw new Error(`Failed to parse JSON: ${secondError.message}`);
        }
      }
      
      throw new Error(`Invalid JSON format: ${parseError.message}`);
    }
  }

  async getStrategyRecommendations(params) {
    if (!this.apiKey) return null;

    const messages = [
      {
        role: "system",
        content: `You are an expert in route generation. 
          Given JSON parameters describing a sport route request,
          return a JSON array ordered from best to worst of strategy names to try. 
          Available strategies: ["organic_adaptive", "surface_optimized", "elevation_aware", "adaptive_fallback"].
          Only return a valid JSON array, nothing else.`,
      },
      {
        role: "user",
        content: JSON.stringify(params),
      },
    ];

    const body = {
      model: this.model,
      messages,
      max_tokens: 64,
      temperature: 0.4,
    };

    try {
      const response = await axios.post(this.baseUrl, body, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        timeout: 15000,
      });

      const text = response.data.choices?.[0]?.message?.content?.trim();
      if (!text) {
        logger.warn("Empty response from Groq API");
        return null;
      }

      const strategies = this._cleanAndParseJSON(text);
      
      if (!Array.isArray(strategies)) {
        logger.warn("Groq response is not an array", { response: strategies });
        return null;
      }

      logger.info("Groq strategy recommendations received", { 
        strategiesCount: strategies.length,
        strategies: strategies.slice(0, 3) // Log first 3 for debugging
      });

      return strategies;
    } catch (error) {
      logger.warn("Groq recommendation error", { 
        error: error.message,
        stack: error.stack?.split('\n')[0] // Premier ligne du stack seulement
      });
      return null;
    }
  }

  async suggestGenerationTweaks(params) {
    if (!this.apiKey) return null;

    const messages = [
      {
        role: "system",
        content:
          "You are an expert sports route planner. " +
          "Given JSON parameters describing a route request, " +
          "return a JSON object with parameter tweaks that could improve the route. " +
          "Available fields: distanceKm, preferredWaypoints, surfacePreference, avoidHighways, prioritizeParks. " +
          "Only include the fields to change. Return only valid JSON, nothing else.",
      },
      {
        role: "user",
        content: JSON.stringify(params),
      },
    ];

    const body = {
      model: this.model,
      messages,
      max_tokens: 128,
      temperature: 0.4,
    };

    try {
      const response = await axios.post(this.baseUrl, body, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        timeout: 15000,
      });

      const text = response.data.choices?.[0]?.message?.content?.trim();
      if (!text) {
        logger.warn("Empty response from Groq tweaks API");
        return null;
      }

      const tweaks = this._cleanAndParseJSON(text);
      
      if (!tweaks || typeof tweaks !== 'object' || Array.isArray(tweaks)) {
        logger.warn("Groq tweaks response is not a valid object", { response: tweaks });
        return null;
      }

      logger.info("Groq tweaks suggestions received", { 
        tweaksCount: Object.keys(tweaks).length,
        tweaks
      });

      return tweaks;
    } catch (error) {
      logger.warn("Groq tweak suggestion error", { 
        error: error.message,
        stack: error.stack?.split('\n')[0]
      });
      return null;
    }
  }
}

module.exports = new GroqService();
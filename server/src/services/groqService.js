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

  async getStrategyRecommendations(params) {
    if (!this.apiKey) return null;

    const messages = [
      {
        role: "system",
        content: ```You are an expert in route generation. 
          Given JSON parameters describing a sport route request,
          return a JSON array ordered from best to worst of strategy names to try. 
          Only return the JSON array.```,
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
      const strategies = JSON.parse(text);
      return Array.isArray(strategies) ? strategies : null;
    } catch (error) {
      logger.warn("Groq recommendation error", error.message);
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
          "Only include the fields to change.",
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
      const tweaks = JSON.parse(text);
      return tweaks && typeof tweaks === "object" ? tweaks : null;
    } catch (error) {
      logger.warn("Groq tweak suggestion error", error.message);
      return null;
    }
  }
}

module.exports = new GroqService();

const express = require('express');
const path = require('path');
const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');
const logger = require('../config/logger');

const router = express.Router();

// Configuration Supabase pour le serveur
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Cache du fichier HTML pour éviter de le relire à chaque requête
let resetPasswordHtml = null;

/**
 * Charge le fichier HTML de reset password (avec cache)
 */
function loadResetPasswordHtml() {
  if (resetPasswordHtml === null) {
    try {
      const htmlPath = path.join(__dirname, '../views/reset-password.html');
      resetPasswordHtml = fs.readFileSync(htmlPath, 'utf8');
      logger.info('Template reset-password.html chargé avec succès');
    } catch (error) {
      logger.error('Erreur chargement template reset-password.html:', error);
      throw new Error('Template HTML non trouvé');
    }
  }
  return resetPasswordHtml;
}

/**
 * Page de réinitialisation de mot de passe
 * Accessible via: https://votre-serveur/auth/reset-password?access_token=...&refresh_token=...
 */
router.get('/reset-password', (req, res) => {
  try {
    const { access_token, refresh_token, type } = req.query;
    
    // Vérifier que c'est bien un reset password
    if (type !== 'recovery') {
      logger.warn('Tentative d\'accès reset-password avec type invalide:', type);
      return res.status(400).send(`
        <html>
          <body style="font-family: Arial; text-align: center; padding: 50px;">
            <h1>❌ Lien invalide</h1>
            <p>Ce lien de réinitialisation n'est pas valide.</p>
          </body>
        </html>
      `);
    }
    
    if (!access_token) {
      logger.warn('Tentative d\'accès reset-password sans token');
      return res.status(400).send(`
        <html>
          <body style="font-family: Arial; text-align: center; padding: 50px;">
            <h1>⏰ Lien expiré</h1>
            <p>Ce lien de réinitialisation a expiré ou est invalide.</p>
            <p>Veuillez demander un nouveau lien depuis l'application.</p>
          </body>
        </html>
      `);
    }
    
    // Charger et servir le template HTML
    const htmlContent = loadResetPasswordHtml();
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(htmlContent);
    
    logger.info('Page reset-password servie', {
      hasToken: !!access_token,
      hasRefreshToken: !!refresh_token,
      type: type,
      userAgent: req.get('user-agent'),
      ip: req.ip
    });
    
  } catch (error) {
    logger.error('Erreur page reset-password:', error);
    res.status(500).send(`
      <html>
        <body style="font-family: Arial; text-align: center; padding: 50px;">
          <h1>🚨 Erreur serveur</h1>
          <p>Une erreur est survenue. Veuillez réessayer plus tard.</p>
        </body>
      </html>
    `);
  }
});

/**
 * API pour mettre à jour le mot de passe
 * POST /api/auth/update-password
 */
router.post('/update-password', async (req, res) => {
  try {
    const { access_token, refresh_token, new_password } = req.body;
    
    if (!access_token || !new_password) {
      return res.status(400).json({
        success: false,
        error: 'Token et nouveau mot de passe requis'
      });
    }
    
    // Validation du mot de passe côté serveur
    const passwordValidation = validatePassword(new_password);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        error: passwordValidation.error
      });
    }
    
    // Créer un client Supabase avec le token de l'utilisateur
    const userSupabase = createClient(supabaseUrl, process.env.SUPABASE_ANON_KEY);
    
    // Définir la session avec le token
    const { data: sessionData, error: sessionError } = await userSupabase.auth.setSession({
      access_token,
      refresh_token
    });
    
    if (sessionError || !sessionData.user) {
      logger.error('Erreur validation token:', sessionError);
      return res.status(401).json({
        success: false,
        error: 'Token invalide ou expiré'
      });
    }
    
    // Mettre à jour le mot de passe
    const { error: updateError } = await userSupabase.auth.updateUser({
      password: new_password
    });
    
    if (updateError) {
      logger.error('Erreur mise à jour mot de passe:', updateError);
      return res.status(400).json({
        success: false,
        error: 'Impossible de mettre à jour le mot de passe'
      });
    }
    
    logger.info('Mot de passe mis à jour avec succès', {
      userId: sessionData.user.id,
      email: sessionData.user.email,
      timestamp: new Date().toISOString()
    });
    
    res.json({
      success: true,
      message: 'Mot de passe mis à jour avec succès'
    });
    
  } catch (error) {
    logger.error('Erreur update-password:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur'
    });
  }
});

/**
 * Valide un mot de passe selon les critères de sécurité
 */
function validatePassword(password) {
  if (!password || password.length < 8) {
    return {
      isValid: false,
      error: 'Le mot de passe doit contenir au moins 8 caractères'
    };
  }
  
  if (!/[A-Z]/.test(password)) {
    return {
      isValid: false,
      error: 'Le mot de passe doit contenir au moins une majuscule'
    };
  }
  
  if (!/[a-z]/.test(password)) {
    return {
      isValid: false,
      error: 'Le mot de passe doit contenir au moins une minuscule'
    };
  }
  
  if (!/[0-9]/.test(password)) {
    return {
      isValid: false,
      error: 'Le mot de passe doit contenir au moins un chiffre'
    };
  }
  
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    return {
      isValid: false,
      error: 'Le mot de passe doit contenir au moins un caractère spécial'
    };
  }
  
  return { isValid: true };
}

/**
 * Route de test pour vérifier que les routes auth fonctionnent
 * À SUPPRIMER en production
 */
router.get('/test', (req, res) => {
  res.json({ 
    success: true, 
    message: 'Routes d\'authentification chargées correctement!',
    timestamp: new Date().toISOString(),
    availableRoutes: [
      'GET /auth/reset-password',
      'POST /auth/update-password',
      'GET /auth/test (development only)'
    ]
  });
});

/**
 * Route pour vérifier la santé du service auth
 */
router.get('/health', (req, res) => {
  const supabaseConfigured = !!(supabaseUrl && process.env.SUPABASE_ANON_KEY && supabaseServiceKey);
  const templateExists = fs.existsSync(path.join(__dirname, '../views/reset-password.html'));
  
  res.json({
    success: true,
    service: 'auth',
    status: 'healthy',
    checks: {
      supabaseConfigured,
      templateExists,
      timestamp: new Date().toISOString()
    }
  });
});

// Middleware de gestion d'erreur spécifique aux routes auth
router.use((error, req, res, next) => {
  logger.error('Auth route error:', error);
  
  if (error.message.includes('Template HTML non trouvé')) {
    return res.status(500).json({
      success: false,
      error: 'Configuration du serveur incomplète'
    });
  }
  
  res.status(500).json({
    success: false,
    error: 'Erreur interne du service d\'authentification',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
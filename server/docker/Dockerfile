# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci --only=production

# Production stage
FROM node:18-alpine

# Installer dumb-init pour une meilleure gestion des signaux
RUN apk add --no-cache dumb-init

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

WORKDIR /app

# Copier les dépendances depuis le builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copier le code source
COPY --chown=nodejs:nodejs . .

# Créer les dossiers nécessaires
RUN mkdir -p logs data && chown -R nodejs:nodejs logs data

# Utiliser l'utilisateur non-root
USER nodejs

# Exposer le port
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Démarrer avec dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
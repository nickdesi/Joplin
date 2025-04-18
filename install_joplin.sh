#!/bin/bash

#------------------------------------------------------------------------------
# Script d'installation simplifié pour Joplin Server dans un LXC Proxmox
# Utilise Docker et Docker Compose.
# À exécuter en tant que root DANS le conteneur LXC (Debian/Ubuntu).
#------------------------------------------------------------------------------

set -e # Quitte immédiatement si une commande échoue
# set -x # Décommentez pour un débogage détaillé

# --- Variables Configurables ---
JOPLIN_DIR="/opt/joplin"         # Répertoire d'installation de Joplin
APP_PORT="22300"                 # Port hôte pour accéder à Joplin Server
DB_PASSWORD=$(openssl rand -base64 16) # Génère un mot de passe BDD plus long

# --- Fonctions ---
# ... (collez ici toutes les fonctions: log_info, log_warn, log_error, prepare_system, install_docker, setup_joplin_config, start_joplin) ...
log_info() {
  echo "[INFO] $1"
}
log_warn() {
  echo "[WARN] $1"
}
log_error() {
  echo "[ERROR] $1" >&2
  exit 1
}
prepare_system() {
  log_info "Mise à jour des paquets et installation des dépendances..."
  apt-get update
  apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    openssl
  apt-get clean
}
install_docker() {
  if command -v docker &> /dev/null; then
    log_info "Docker semble déjà installé. Vérification de la version..."
    docker --version
    docker compose version
    return 0
  fi
  log_info "Installation de Docker CE et Docker Compose..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  log_info "Installation des paquets Docker..."
  apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  log_info "Vérification du service Docker..."
  systemctl enable --now docker
  if ! systemctl is-active --quiet docker; then
      log_error "Le service Docker n'a pas pu démarrer."
  fi
  log_info "Docker CE et Docker Compose installés et démarrés."
}
setup_joplin_config() {
  log_info "Configuration de Joplin Server..."
  CONTAINER_IP=$(hostname -I | awk '{print $1}')
  if [ -z "${CONTAINER_IP}" ]; then
      log_warn "Impossible de déterminer l'IP du conteneur automatiquement."
      log_warn "APP_BASE_URL sera configurée avec 'http://localhost:${APP_PORT}'."
      log_warn "Vous DEVREZ la modifier manuellement dans ${JOPLIN_DIR}/docker-compose.yml si vous accédez depuis une autre machine."
      CONTAINER_IP="localhost"
  else
      log_info "IP détectée pour le conteneur : ${CONTAINER_IP}"
  fi
  mkdir -p "${JOPLIN_DIR}/data/postgres"
  cd "${JOPLIN_DIR}" || log_error "Impossible de se déplacer dans ${JOPLIN_DIR}"
  log_info "Création du fichier docker-compose.yml dans ${JOPLIN_DIR}..."
  cat << EOF > docker-compose.yml
# Configuration Docker Compose pour Joplin Server
# Généré par script d'installation

version: '3.8'

services:
  db:
    image: postgres:15
    container_name: joplin_db
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    restart: unless-stopped
    environment:
      POSTGRES_DB: joplin
      POSTGRES_USER: joplin
      POSTGRES_PASSWORD: "${DB_PASSWORD}"

  app:
    image: joplin/server:latest
    container_name: joplin_server
    depends_on:
      - db
    ports:
      - "${APP_PORT}:22300"
    restart: unless-stopped
    environment:
      APP_PORT: '22300'
      APP_BASE_URL: "http://${CONTAINER_IP}:${APP_PORT}"
      DB_CLIENT: pg
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
      POSTGRES_DATABASE: joplin
      POSTGRES_USER: joplin
      POSTGRES_PASSWORD: "${DB_PASSWORD}"
      # --- Autres configurations optionnelles (décommentez et ajustez si besoin) ---
      # MAILER_ENABLED: '1'
      # MAILER_HOST: 'smtp.example.com'
      # MAILER_PORT: '587'
      # MAILER_SECURITY: 'tls'
      # MAILER_AUTH_USER: 'votre_email@example.com'
      # MAILER_AUTH_PASSWORD: 'votre_mot_de_passe_smtp'
      # MAILER_NOREPLY_NAME: 'Joplin Server'
      # MAILER_NOREPLY_EMAIL: 'noreply@joplin.example.com'
EOF
  log_info "Fichier docker-compose.yml créé."
}
start_joplin() {
  log_info "Démarrage des conteneurs Joplin Server (cela peut prendre un moment la première fois)..."
  cd "${JOPLIN_DIR}" || log_error "Impossible de se déplacer dans ${JOPLIN_DIR}"
  docker compose up -d
  log_info "Attente de 15 secondes pour le démarrage des services..."
  sleep 15
  log_info "Vérification de l'état des conteneurs..."
  docker compose ps
}


# --- Exécution du script ---

log_info "--- Début de l'installation de Joplin Server ---"

prepare_system
install_docker
setup_joplin_config
start_joplin

# ... (collez ici toute la section de sortie finale avec les echo) ...
log_info "--- Installation terminée ! ---"
echo ""
echo "---------------------------------------------------------------------"
echo " Accès à Joplin Server :"
echo "    URL: http://${CONTAINER_IP}:${APP_PORT}"
echo ""
echo " Identifiants administrateur par défaut :"
echo "    Email: admin@localhost"
echo "    Mot de passe: admin"
echo ""
echo " >> [IMPORTANT] Changez le mot de passe administrateur immédiatement"
echo "    lors de votre première connexion à l'interface web !"
echo "---------------------------------------------------------------------"
echo ""
echo " Mot de passe généré pour la base de données PostgreSQL :"
echo "    Utilisateur: joplin"
echo "    Mot de passe: ${DB_PASSWORD}"
echo "    (Ce mot de passe est stocké dans ${JOPLIN_DIR}/docker-compose.yml)"
echo ""
echo "---------------------------------------------------------------------"
echo " [IMPORTANT - Reverse Proxy]"
echo " Si vous prévoyez d'accéder à Joplin depuis l'extérieur de votre réseau"
echo " ou via un nom de domaine (ex: https://joplin.mondomaine.com),"
echo " vous DEVEZ configurer un reverse proxy (ex: Nginx Proxy Manager, Traefik)."
echo ""
echo " Vous devrez ensuite :"
echo " 1. Modifier le fichier : ${JOPLIN_DIR}/docker-compose.yml"
echo " 2. Mettre à jour la variable 'APP_BASE_URL' avec votre URL publique"
echo "    (ex: APP_BASE_URL=https://joplin.mondomaine.com)"
echo " 3. Redémarrer les conteneurs dans le dossier ${JOPLIN_DIR} avec :"
echo "    cd ${JOPLIN_DIR} && docker compose down && docker compose up -d"
echo "---------------------------------------------------------------------"


exit 0

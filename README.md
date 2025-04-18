# Joplin Server Installer pour Proxmox LXC (via Docker)

Ce script simplifie l'installation de [Joplin Server](https://joplinapp.org/help/user/server/install/) dans un conteneur LXC sous Proxmox VE, en utilisant Docker et Docker Compose.

## Fonctionnalités

*   Mise à jour du système et installation des dépendances.
*   Installation de Docker CE et Docker Compose (plugin v2).
*   Génération automatique d'un mot de passe sécurisé pour la base de données.
*   Configuration d'un fichier `docker-compose.yml` pour Joplin Server et sa base de données PostgreSQL.
*   Démarrage des services Joplin Server.
*   Instructions claires pour la post-installation et la configuration d'un reverse proxy.

## Prérequis

1.  Un hyperviseur Proxmox VE fonctionnel.
2.  Un modèle (template) de conteneur LXC Debian (Bullseye ou Bookworm recommandé) ou Ubuntu (LTS recommandé) téléchargé sur Proxmox.
3.  Un conteneur LXC créé à partir de ce modèle, avec accès à Internet.
4.  Accès `root` (ou la possibilité d'utiliser `sudo`) à l'intérieur du conteneur LXC.

## Utilisation

1.  **Accéder au Conteneur LXC :**
    Connectez-vous à votre conteneur LXC Proxmox via la console web ou SSH. Assurez-vous d'être l'utilisateur `root`.

2.  **Télécharger le Script :**
    Vous pouvez soit cloner ce dépôt, soit télécharger directement le script :
    ```
    # Option A: Cloner le dépôt (si git est installé)
    # apt update && apt install -y git # Si git n'est pas installé
    # git clone https://github.com/VOTRE_UTILISATEUR/VOTRE_REPO.git
    # cd VOTRE_REPO

    # Option B: Télécharger le script directement
    curl -Lo install_joplin.sh https://raw.githubusercontent.com/VOTRE_UTILISATEUR/VOTRE_REPO/main/install_joplin.sh
    ```
    *Remplacez `VOTRE_UTILISATEUR/VOTRE_REPO` par le chemin réel de votre dépôt après l'avoir créé.*

3.  **Rendre le Script Exécutable :**
    ```
    chmod +x install_joplin.sh
    ```

4.  **Exécuter le Script :**
    Lancez le script en tant que `root`.
    ```
    ./install_joplin.sh
    ```

5.  **Suivre les Instructions :**
    Le script vous guidera à travers les étapes. À la fin, il affichera l'URL d'accès, les identifiants par défaut et le mot de passe de la base de données généré.

## Post-Installation

*   **Accès Web :** Ouvrez l'URL fournie (`http://<IP_DU_CONTENEUR>:22300` par défaut) dans votre navigateur.
*   **Identifiants Admin :** Connectez-vous avec l'email `admin@localhost` et le mot de passe `admin`.
*   **!!! SÉCURITÉ IMPORTANTE !!! :** Changez immédiatement le mot de passe de l'administrateur après votre première connexion via l'interface web d'administration.
*   **Mot de Passe BDD :** Le mot de passe généré pour l'utilisateur `joplin` de la base de données PostgreSQL est affiché à la fin du script et est configuré dans `/opt/joplin/docker-compose.yml`. Conservez-le en lieu sûr si nécessaire, bien que vous n'ayez généralement pas besoin d'y toucher.

## Configuration d'un Reverse Proxy (Recommandé)

Pour accéder à Joplin Server de manière sécurisée depuis l'extérieur de votre réseau local ou via un nom de domaine (ex: `https://joplin.votredomaine.com`), **il est fortement recommandé de configurer un reverse proxy** (comme Nginx Proxy Manager, Caddy, Traefik, ou Apache).

Une fois votre reverse proxy configuré pour pointer vers `http://<IP_DU_CONTENEUR>:22300` et gérer le SSL (HTTPS) :

1.  **Modifiez le fichier de configuration Docker Compose :**
    ```
    nano /opt/joplin/docker-compose.yml
    ```
2.  **Mettez à jour la variable `APP_BASE_URL`** dans la section `environment` du service `app` avec votre URL publique complète (incluant `https://`) :
    ```
    environment:
      # ... autres variables ...
      APP_BASE_URL: "https://joplin.votredomaine.com" # <= MODIFIEZ CECI
      # ... autres variables ...
    ```
3.  **Redémarrez les conteneurs Joplin** pour appliquer le changement :
    ```
    cd /opt/joplin
    docker compose down
    docker compose up -d
    ```

## Personnalisation

Vous pouvez modifier les variables au début du script `install_joplin.sh` avant de l'exécuter si vous souhaitez changer le répertoire d'installation (`JOPLIN_DIR`) ou le port d'accès hôte (`APP_PORT`).

## Licence

Ce projet est sous licence [MIT](LICENSE). Voir le fichier `LICENSE` pour plus de détails.

## Avertissement

Ce script est fourni tel quel. Utilisez-le à vos propres risques. Assurez-vous de comprendre ce que fait le script avant de l'exécuter, en particulier sur un système contenant des données importantes.

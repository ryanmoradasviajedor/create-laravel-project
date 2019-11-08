#!/usr/bin/env bash
# This script is expected be run on Mac OSX.

# Color code definitions for printing messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color


###############################################################################
# Check requirements
###############################################################################
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check .env file exists
if [[ ! -f .env ]]; then
    echo -e "${RED}Missing .env file.${NC}"
    echo -e "${YELLOW}Creating .env referring '.env.example.dist'.${NC}"
    cp ${SCRIPT_DIR}/.env.example.dist ${SCRIPT_DIR}/.env
    echo -e "${GREEN}.env file created successfully!!!${NC}"
fi

# Load .env just created
export $(cat .env | grep -v '^#' | xargs)

APP_DIR=${WEB_APP_DIR}/${APP_NAME}

# Stop, if the directory already exists
if [[ -d "${APP_DIR}" ]]; then
    echo "Directory '${APP_DIR}' already exists. Stop creating project."
    exit 1
fi

# Check if Docker daemon running
status=`docker inspect -f {{.State.Running}} $WEB_APP_CONTAINER_NAME`
if [[ $? != 0 || "$status" = "false" ]]; then # container not exist yet
    echo -e "${YELLOW}Please make sure Docker container is running next time.${NC}"
    echo -e "${YELLOW}Don't worry I will run it for you.${NC}"
    cd $WEB_APP_CONTAINER_DIR
    ./start.sh
fi

# Let script stop on command error
set -e

# Confirm install directory
echo "New application source code will be generated at: "
echo -e "    ${CYAN}${APP_DIR}${NC}"
read -p "Is this OK? [y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]];then
    echo -e "Not OK. Exiting..."
    exit 1
fi

# Confirm if database is prepared already
read -p "Have you prepared database for this project? [y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]];then
    echo -e "Please create database before continue."
    echo -e "From your local machine, login to MySQL;"
    echo -e "${GREEN}mysql -h 127.0.0.1 -P 53306 -u root -proot${NC}\n"
    echo -e "Create MySQL user and database;"
    echo -e "${GREEN}CREATE USER '${RED}my_user${GREEN}'@'%' IDENTIFIED BY '${RED}my_password${GREEN}';${NC}";
    echo -e "${GREEN}CREATE DATABASE IF NOT EXISTS \`${RED}my_database${GREEN}\`;${NC}";
    echo -e "${GREEN}GRANT USAGE ON \`${RED}my_database${GREEN}\`.* TO '${RED}my_user${GREEN}'@'%';${NC}";
    echo -e "${GREEN}GRANT ALL PRIVILEGES ON \`${RED}my_database${GREEN}\`.* TO '${RED}my_user${GREEN}'@'%';${NC}";
    exit 1
fi

# Let script stop on command error
set -e

###############################################################################
# Install bare Laravel
###############################################################################
echo -e "Creating Laravel application project ${GREEN}${APP_NAME}${NC} in"
echo -e "  ${CYAN}${APP_DIR}${NC}..."

set -x

# Workaround to make composer faster
composer config --global repo.packagist composer https://packagist.org

# Install bare Laravel
composer create-project --prefer-dist laravel/laravel $APP_DIR

cd $APP_DIR
#echo "You successfully created a new laravel application!!!"

###############################################################################
# Copy Nginx configuration for local development environment
###############################################################################
cp -R ${SCRIPT_DIR}/templates/_dev ./.dev
sed -i '' \
  -e "s#root /var/www/html/.*#root /var/www/html/${APP_NAME};#g" \
  -e "s#server_name localhost-.*#server_name localhost-${APP_NAME};#g" \
  .dev/nginx/local-docker.conf

cd $WEB_APP_CONTAINER_DIR
./restart.sh
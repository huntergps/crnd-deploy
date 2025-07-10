#!/bin/bash

# CRND Deploy - la forma simple de iniciar una nueva instancia de Odoo lista para producción.
# Copyright (C) 2020  Center of Research and Development
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# ADVERTENCIA: Debe ejecutarse bajo SUDO

# NOTA: Instala automáticamente odoo-helper-scripts si no está instalado aún

# Soporta pasar parámetros como variables de entorno y como argumentos al script
# Variables de entorno y valores por defecto:
#   ODOO_USER=odoo
#   ODOO_INSTALL_DIR=/opt/odoo
#   ODOO_DB_HOST=localhost
#   ODOO_DB_USER=odoo
#   ODOO_DB_PASSWORD=odoo
#   ODOO_REPO=https://github.com/odoo/odoo
#   ODOO_BRANCH=12.0
#   ODOO_VERSION=12.0
#   ODOO_WORKERS=2
#
# También alguna configuración puede pasarse como argumentos de línea de comandos:
#   sudo bash crnd-deploy.bash <db_host> <db_user> <db_pass>
# 

#--------------------------------------------------
# Parámetros del script
#--------------------------------------------------
SCRIPT=$0;
SCRIPT_NAME=$(basename $SCRIPT);
SCRIPT_DIR=$(dirname $SCRIPT);
SCRIPT_PATH=$(readlink -f $SCRIPT);
NGIX_CONF_GEN="$SCRIPT_DIR/gen_nginx.py";

WORKDIR=`pwd`;

#--------------------------------------------------
# Versión
#--------------------------------------------------
CRND_DEPLOY_VERSION="1.0.0"

#--------------------------------------------------
# Valores por defecto - Solo Odoo 17+ soportado
#--------------------------------------------------
DEFAULT_ODOO_BRANCH=saas-18.3
DEFAULT_ODOO_VERSION=saas-18.3
MINIMUM_SUPPORTED_VERSION=17.0

#--------------------------------------------------
# Validar versión de Odoo - Solo 17+ permitido
#--------------------------------------------------
function validate_odoo_version {
    local version=$1;
    
    # Extraer versión numérica
    local numeric_version;
    if [[ "$version" == saas-* ]]; then
        # Para versiones SaaS como saas-18.1, saas-18.2, saas-18.3
        numeric_version="${version#saas-}";
    else
        # Para versiones estándar como 17.0, 18.0
        numeric_version="$version";
    fi
    
    # Convertir a formato comparable (17.0 -> 1700, 18.3 -> 1830)
    local major;
    local minor;
    if [[ "$numeric_version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}";
        minor="${BASH_REMATCH[2]}";
    elif [[ "$numeric_version" =~ ^([0-9]+)$ ]]; then
        major="$numeric_version";
        minor="0";
    else
        echo -e "${REDC}ERROR${NC}: Formato de versión inválido: $version";
        echo -e "${YELLOWC}Versiones soportadas: 17.0, 18.0, saas-18.1, saas-18.2, saas-18.3, etc.${NC}";
        return 1;
    fi
    
    local version_number=$((major * 100 + minor));
    local min_version_number=1700; # 17.0
    
    if [ "$version_number" -lt "$min_version_number" ]; then
        echo -e "${REDC}ERROR${NC}: Versión de Odoo ${YELLOWC}$version${NC} no soportada.";
        echo -e "${YELLOWC}Este script solo soporta Odoo 17.0 o superior.${NC}";
        echo -e "${BLUEC}Razones:${NC}";
        echo -e "  • Python 3.8+ requerido (Ubuntu 22.04+)";
        echo -e "  • Arquitectura moderna de Odoo";
        echo -e "  • Dependencias actualizadas";
        echo -e "${YELLOWC}Versiones soportadas: 17.0, 18.0, saas-18.1, saas-18.2, saas-18.3${NC}";
        return 1;
    fi
    
    # Validar que tenemos Python 3.8+ para Odoo 17+
    if ! python3 -c "import sys; assert sys.version_info >= (3, 8), 'Python 3.8+ requerido para Odoo 17+'" 2>/dev/null; then
        echo -e "${REDC}ERROR${NC}: Python 3.8+ es requerido para Odoo 17+";
        echo -e "${YELLOWC}Tu versión actual: $(python3 --version)${NC}";
        echo -e "${BLUEC}Instala Python 3.8+ o usa Ubuntu 22.04+${NC}";
        return 1;
    fi
    
    echo -e "${GREENC}✓${NC} Versión de Odoo ${YELLOWC}$version${NC} soportada";
    return 0;
}

#--------------------------------------------------
# Analizar variables de entorno
#--------------------------------------------------
ODOO_REPO=${ODOO_REPO:-https://github.com/odoo/odoo};
ODOO_BRANCH=${ODOO_BRANCH:-$DEFAULT_ODOO_BRANCH};
ODOO_VERSION=${ODOO_VERSION:-$DEFAULT_ODOO_VERSION};
ODOO_USER=${ODOO_USER:-odoo};
ODOO_WORKERS=${ODOO_WORKERS:-2};
PROJECT_ROOT_DIR=${ODOO_INSTALL_DIR:-/opt/odoo};
DB_HOST=${ODOO_DB_HOST:-localhost};
DB_USER=${ODOO_DB_USER:-odoo};
DB_PASSWORD=${ODOO_DB_PASSWORD:-odoo};
INSTALL_MODE=${INSTALL_MODE:-git};


#--------------------------------------------------
# Definir variables de color
#--------------------------------------------------
NC='\e[0m';
REDC='\e[31m';
GREENC='\e[32m';
YELLOWC='\e[33m';
BLUEC='\e[34m';
LBLUEC='\e[94m';


if [[ $UID != 0 ]]; then
    echo -e "${REDC}ERROR${NC}";
    echo -e "${YELLOWC}Por favor ejecuta este script con sudo:${NC}"
    echo -e "${BLUEC}sudo $0 $* ${NC}"
    exit 1
fi


#--------------------------------------------------
# FN: Imprimir uso
#--------------------------------------------------
function print_usage {

    echo "
Uso:

    crnd-deploy.bash [opciones]    - instalar odoo

Opciones:

    --odoo-repo <repo>       - repositorio git para clonar odoo desde.
                               por defecto: $ODOO_REPO
    --odoo-branch <branch>   - rama de odoo para clonar.
                               por defecto: $ODOO_BRANCH
    --odoo-version <version> - versión de odoo para clonar.
                               por defecto: $ODOO_VERSION
    --odoo-user <user>       - nombre del usuario del sistema para ejecutar odoo con.
                               por defecto: $ODOO_USER
    --db-host <host>         - host de base de datos a usar por odoo.
                               por defecto: $DB_HOST
    --db-user <user>         - usuario de base de datos para conectar a la db
                               por defecto: $DB_USER
    --db-password <password> - contraseña de base de datos para conectar a la db
                               por defecto: $DB_PASSWORD
    --install-dir <path>     - directorio para instalar odoo en
                               por defecto: $PROJECT_ROOT_DIR
    --install-mode <mode>    - modo de instalación. puede ser: 'git', 'archive'
                               por defecto: $INSTALL_MODE
    --local-postgres         - instalar instancia local de servidor postgresql
    --proxy-mode             - Establece esta opción si planeas ejecutar odoo
                               detrás de proxy (nginx, etc)
    --workers <workers>      - número de workers a ejecutar.
                               Por defecto: $ODOO_WORKERS
    --local-nginx            - instalar nginx local y configurarlo para esta
                               instancia de odoo
    --odoo-helper-dev        - Si se establece entonces usar versión dev de odoo-helper
    --install-ua-locales     - Si se establece entonces instalar también uk_UA y ru_RU
                               locales del sistema.
    -v|--version             - imprimir versión y salir
    -h|--help|help           - mostrar este mensaje de ayuda

Sugerencia:

    Echa un vistazo al proyecto [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit),
    y descubre la forma más fácil de gestionar tu instalación de odoo.

    Solo notas breves sobre [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit):
        - iniciar nueva instancia de odoo lista para producción en 1-2 minutos.
        - agregar complementos personalizados a tus instancias de odoo en 5-10 minutos.
        - configuración de email lista para usar: solo presiona botón y
          agrega algunos registros a tu DNS, y obtén un email funcionando
        - hacer tu instancia de odoo disponible al mundo externo en 30 segundos:
          solo agrega un solo registro en tu DNS

    Si tienes alguna pregunta, entonces contáctanos en
    [info@crnd.pro](mailto:info@crnd.pro),
    así podemos programar una demostración en línea.

---
Versión: ${CRND_DEPLOY_VERSION}
";
}

#--------------------------------------------------
# Analizar línea de comandos
#--------------------------------------------------
while [[ $# -gt 0 ]]
do
    key="$1";
    case $key in
        --odoo-repo)
            ODOO_REPO=$2;
            shift;
        ;;
        --odoo-branch)
            ODOO_BRANCH=$2;
            shift;
        ;;
        --odoo-version)
            ODOO_VERSION=$2;
            shift;
            
            # Validar versión antes de continuar
            if ! validate_odoo_version "$ODOO_VERSION"; then
                exit 1;
            fi

            if [ "$ODOO_VERSION" != "$DEFAULT_ODOO_VERSION" ] && [ "$ODOO_BRANCH" == "$DEFAULT_ODOO_BRANCH" ]; then
                ODOO_BRANCH=$ODOO_VERSION;
            fi
        ;;
        --odoo-user)
            ODOO_USER=$2;
            shift;
        ;;
        --db-host)
            DB_HOST=$2;
            shift;
        ;;
        --db-user)
            DB_USER=$2;
            shift;
        ;;
        --db-password)
            DB_PASSWORD=$2;
            shift;
        ;;
        --install-dir)
            PROJECT_ROOT_DIR=$2;
            shift;
        ;;
        --install-mode)
            if [ "$2" != "git" ] && [ "$2" != "archive" ]; then
                echo "ERROR: Wrong install mode specified: $2"
                exit 1;
            fi
            INSTALL_MODE=$2;
            shift;
        ;;
        --workers)
            ODOO_WORKERS=$2;
            shift;
        ;;
        --proxy-mode)
            PROXY_MODE=1;
        ;;
        --local-postgres)
            # Generar contraseña aleatoria para la base de datos
            DB_HOST="localhost";
            DB_PASSWORD="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)";
            INSTALL_LOCAL_POSTGRES=1;
        ;;
        --local-nginx)
            INSTALL_LOCAL_NGINX=1;
            PROXY_MODE=1;
        ;;
        --odoo-helper-dev)
            USE_DEV_VERSION_OF_ODOO_HElPER=1;
        ;;
        --install-ua-locales)
            CRND_DEPLOY_INSTALL_UA_LOCALES=1;
        ;;
        -v|--version)
            echo "$CRND_DEPLOY_VERSION";
            exit 0;
        ;;
        -h|--help|help)
            print_usage;
            exit 0;
        ;;
        *)
            echo "Unknown option global option /command $key";
            echo "Use --help option to get info about available options.";
            exit 1;
        ;;
    esac;
    shift;
done;
#--------------------------------------------------


set -e;   # fail on errors

#--------------------------------------------------
# Validar configuración inicial
#--------------------------------------------------
echo -e "\n${BLUEC}Validando configuración de Odoo...${NC}\n";

# Validar versión por defecto al inicio
if ! validate_odoo_version "$ODOO_VERSION"; then
    exit 1;
fi

#--------------------------------------------------
# Actualizar Servidor y Instalar Dependencias
#--------------------------------------------------
echo -e "\n${BLUEC}Actualizar Servidor...${NC}\n";
sudo apt-get update -qq;
sudo apt-get upgrade -qq -y;
echo -e "\n${BLUEC}Instalando dependencias básicas...${NC}\n";
sudo apt-get install -qqq -y \
    wget locales software-properties-common;

# Instalar Python 3.8+ para Odoo 17+
echo -e "\n${BLUEC}Verificando e instalando Python 3.8+...${NC}\n";

# Verificar Python actual
CURRENT_PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo -e "${BLUEC}Python actual: ${YELLOWC}$CURRENT_PYTHON_VERSION${NC}";

# Determinar qué versión de Python instalar basado en la versión de Odoo
local odoo_major;
if [[ "$ODOO_VERSION" == saas-* ]]; then
    odoo_major="${ODOO_VERSION#saas-}";
    odoo_major="${odoo_major%.*}";
else
    odoo_major="${ODOO_VERSION%.*}";
fi

# Instalar Python apropiado según la versión de Odoo
if [ "$odoo_major" -ge 18 ]; then
    # Odoo 18+ requiere Python 3.10+
    if ! python3 -c "import sys; assert sys.version_info >= (3, 10)" 2>/dev/null; then
        echo -e "${BLUEC}Instalando Python 3.10+ para Odoo 18+...${NC}";
        sudo add-apt-repository ppa:deadsnakes/ppa -y;
        sudo apt-get update -qq;
        sudo apt-get install -qqq -y python3.10 python3.10-dev python3.10-venv python3.10-distutils;
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1;
    fi
elif [ "$odoo_major" -eq 17 ]; then
    # Odoo 17 requiere Python 3.8+
    if ! python3 -c "import sys; assert sys.version_info >= (3, 8)" 2>/dev/null; then
        echo -e "${BLUEC}Instalando Python 3.8+ para Odoo 17...${NC}";
        # Ubuntu 22.04 ya tiene Python 3.10 por defecto
        sudo apt-get install -qqq -y python3 python3-dev python3-venv python3-distutils;
    fi
fi

# Verificar versión final de Python
echo -e "\n${BLUEC}Verificando versión final de Python...${NC}\n";
python3 --version;
if ! python3 -c "import sys; assert sys.version_info >= (3, 8), 'Python 3.8+ requerido para Odoo 17+'" 2>/dev/null; then
    echo -e "${REDC}ERROR${NC}: Python 3.8+ es requerido para Odoo 17+";
    exit 1;
fi

#--------------------------------------------------
# Generar locales
#--------------------------------------------------
echo -e "\n${BLUEC}Actualizar locales...${NC}\n";
sudo locale-gen en_US.UTF-8;
sudo locale-gen en_GB.UTF-8;

if [ -n "$CRND_DEPLOY_INSTALL_UA_LOCALES" ]; then
    sudo locale-gen ru_UA.UTF-8;
    sudo locale-gen uk_UA.UTF-8;
fi

update-locale LANG="en_US.UTF-8";
update-locale LANGUAGE="en_US:en";

#--------------------------------------------------
# Asegurar que odoo-helper esté instalado
#--------------------------------------------------
if ! command -v odoo-helper >/dev/null 2>&1; then
    echo -e "${BLUEC}Odoo-helper no instalado! Instalando...${NC}";
    if ! wget -q -T 2 -O /tmp/odoo-helper-install.bash \
            https://raw.githubusercontent.com/huntergps/odoo-helper-scripts/master/install-system.bash; then
        echo "${REDC}ERROR${NC}: No se pudo descargar el instalador de odoo-helper-scripts desde github. Verifica tu conexión de red.";
        exit 1;
    fi

    # Instalar la última versión de odoo-helper scripts
    if [ -z "$USE_DEV_VERSION_OF_ODOO_HElPER" ]; then
        sudo bash /tmp/odoo-helper-install.bash master;
    else
        sudo bash /tmp/odoo-helper-install.bash dev;
    fi

    # Imprimir versión de odoo-helper
    odoo-helper --version;
fi

# Instalar pre-requisitos de odoo
sudo odoo-helper install pre-requirements -y;
sudo odoo-helper install sys-deps -y --branch "$ODOO_BRANCH" "$ODOO_VERSION";

if [ ! -z $INSTALL_LOCAL_POSTGRES ]; then
    sudo odoo-helper install postgres;

    if ! sudo odoo-helper exec postgres_test_connection; then
        echo -e "${YELLOWC}ADVERTENCIA${NC}: Parece que el servidor postgres no se inició, así que muéstralo antes de crear el usuario de la base de datos.";

        # Parece que estamos dentro de un contenedor de docker, así que iniciamos el servidor postgres antes de crear el usuario
        sudo /etc/init.d/postgresql start;
        sudo odoo-helper postgres user-create $DB_USER $DB_PASSWORD;
        sudo /etc/init.d/postgresql stop;
    else
        sudo odoo-helper postgres user-create $DB_USER $DB_PASSWORD;
    fi
fi

#--------------------------------------------------
# Instalar Odoo
#--------------------------------------------------
echo -e "\n${BLUEC}Instalando odoo...${NC}\n";
# importar módulo común de odoo-helper, que contiene algunas funciones útiles
source $(odoo-helper system lib-path common);

# importar bibliotecas de odoo-helper
ohelper_require 'install';
ohelper_require 'config';

# No preguntar confirmación al instalar dependencias
ALWAYS_ANSWER_YES=1;

# Configurar variables por defecto de odoo-helper
config_set_defaults;  # importado desde el módulo común

# definir ruta de complementos a colocar en los archivos de configuración
ADDONS_PATH="$ODOO_PATH/openerp/addons,$ODOO_PATH/odoo/addons,$ODOO_PATH/addons,$ADDONS_DIR";
INIT_SCRIPT="/etc/init.d/odoo";
ODOO_PID_FILE="/var/run/odoo.pid";  # ubicación por defecto del archivo pid de odoo

install_create_project_dir_tree;   # importado desde el módulo 'install'

if [ ! -d $ODOO_PATH ]; then
    if [ "$INSTALL_MODE" == "git" ]; then
        install_clone_odoo;   # importado desde el módulo 'install'
    elif [ "$INSTALL_MODE" == "archive" ]; then
        install_download_odoo;
    else
        echo -e "${REDC}ERROR:${NC} modo de instalación incorrecto especificado: '$INSTALL_MODE'!";
    fi
fi

# instalar odoo en sí
install_odoo_install;  # importado desde el módulo 'install'

# generar archivo de configuración de odoo
declare -A ODOO_CONF_OPTIONS;
ODOO_CONF_OPTIONS[addons_path]="$ADDONS_PATH";
ODOO_CONF_OPTIONS[admin_passwd]="$(random_string 32)";
ODOO_CONF_OPTIONS[data_dir]="$DATA_DIR";
ODOO_CONF_OPTIONS[logfile]="$LOG_FILE";
ODOO_CONF_OPTIONS[db_host]="$DB_HOST";
ODOO_CONF_OPTIONS[db_port]="False";
ODOO_CONF_OPTIONS[db_user]="$DB_USER";
ODOO_CONF_OPTIONS[db_password]="$DB_PASSWORD";
ODOO_CONF_OPTIONS[workers]=$ODOO_WORKERS;

# el archivo pid será manejado por el script de inicialización, no por odoo en sí
ODOO_CONF_OPTIONS[pidfile]="None";

if [ ! -z $PROXY_MODE ]; then
    ODOO_CONF_OPTIONS[proxy_mode]="True";
fi

install_generate_odoo_conf $ODOO_CONF_FILE;   # importado desde el módulo 'install'

# Escribir configuración del proyecto de odoo-helper
echo "#---ODOO-INSTANCE-CONFIG---" >> /etc/$CONF_FILE_NAME;
echo "`config_print`" >> /etc/$CONF_FILE_NAME;

# esto hará que los scripts de odoo-helper ejecuten odoo con el usuario especificado
# (a través de una llamada sudo)
echo "SERVER_RUN_USER=$ODOO_USER;" >> /etc/$CONF_FILE_NAME;

#--------------------------------------------------
# Corregir compatibilidad de addons de odoo 9/10
#--------------------------------------------------
if [ ! -d $ODOO_PATH/openerp/addons ]; then
    sudo mkdir -p $ODOO_PATH/openerp/addons;
fi
if [ ! -d $ODOO_PATH/odoo/addons ]; then
    sudo mkdir -p $ODOO_PATH/odoo/addons;
fi

#--------------------------------------------------
# Crear Usuario Odoo
#--------------------------------------------------
if ! getent passwd $ODOO_USER  > /dev/null; then
    echo -e "\n${BLUEC}Creando usuario Odoo: $ODOO_USER ${NC}\n";
    sudo adduser --system --no-create-home --home $PROJECT_ROOT_DIR \
        --quiet --group $ODOO_USER;
else
    echo -e "\n${YELLOWC}El usuario Odoo ya existe, usando el.${NC}\n";
fi

#--------------------------------------------------
# Crear Script de Inicialización
#--------------------------------------------------
echo -e "\n${BLUEC}Creando script de inicialización${NC}\n";
sudo cp $ODOO_PATH/debian/init /etc/init.d/odoo
sudo chmod a+x /etc/init.d/odoo
sed -i -r "s@DAEMON=(.*)@DAEMON=$(get_server_script)@" /etc/init.d/odoo;
sed -i -r "s@CONFIG=(.*)@CONFIG=$ODOO_CONF_FILE@" /etc/init.d/odoo;
sed -i -r "s@LOGFILE=(.*)@LOGFILE=$LOG_FILE@" /etc/init.d/odoo;
sed -i -r "s@USER=(.*)@USER=$ODOO_USER@" /etc/init.d/odoo;
sed -i -r "s@PIDFILE=(.*)@PIDFILE=$ODOO_PID_FILE@" /etc/init.d/odoo;
sed -i -r "s@PATH=(.*)@PATH=\1:$VENV_DIR/bin@" /etc/init.d/odoo;
sudo update-rc.d odoo defaults

# Archivo de configuración
sudo chown root:$ODOO_USER $ODOO_CONF_FILE;
sudo chmod 0640 $ODOO_CONF_FILE;

# Log
sudo chown $ODOO_USER:$ODOO_USER $LOG_DIR;
sudo chmod 0750 $LOG_DIR

# Directorio de datos
sudo chown $ODOO_USER:$ODOO_USER $DATA_DIR;

# Directorio raíz de Odoo
sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR;

#--------------------------------------------------
# Configurar logrotate
#--------------------------------------------------
echo -e "\n${BLUEC}Configurando logrotate${NC}\n";
sudo cat > /etc/logrotate.d/odoo << EOF
$LOG_DIR/*.log {
    copytruncate
    missingok
    notifempty
}
EOF

echo -e "\n${GREENC}Odoo instalado!${NC}\n";

if [ ! -z $INSTALL_LOCAL_NGINX ]; then
    echo -e "${BLUEC}Instalando y configurando nginx local..,${NC}";
    NGINX_CONF_PATH="/etc/nginx/sites-available/$(hostname).conf";
    sudo apt-get install -qqq -y --no-install-recommends nginx;
    sudo python3 $NGIX_CONF_GEN \
        --instance-name="$(hostname -s)" \
        --frontend-server-name="$(hostname)" > $NGINX_CONF_PATH;
    echo -e "${GREENC}Nginx parece estar instalado y la configuración por defecto se ha generado. ";
    echo -e "Mira $NGINX_CONF_PATH para la configuración de nginx.${NC}";
fi


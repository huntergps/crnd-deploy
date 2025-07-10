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
# Nuevas variables para configuración SSL
#--------------------------------------------------
DOMAIN_NAME=${DOMAIN_NAME:-""};
SSL_EMAIL=${SSL_EMAIL:-""};
ENABLE_SSL=${ENABLE_SSL:-"no"};
NGINX_SSL_CONFIG=${NGINX_SSL_CONFIG:-"yes"};


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
    --domain <domain>        - nombre de dominio para configurar SSL
                               ejemplo: erp1.tecnosmart.com.ec
    --email <email>          - email para certificados SSL de Let's Encrypt
                               ejemplo: admin@tecnosmart.com.ec
    --enable-ssl             - habilitar configuración automática de SSL con certbot
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
            DB_HOST="localhost";
            # Solo usar contraseña por defecto si no se especificó --db-password
            if [ -z "$DB_PASSWORD" ]; then
                DB_PASSWORD="Odoo123";
                echo -e "${BLUEC}Usando contraseña por defecto PostgreSQL: ${YELLOWC}$DB_PASSWORD${NC}";
            else
                echo -e "${BLUEC}Usando contraseña PostgreSQL especificada: ${YELLOWC}$DB_PASSWORD${NC}";
            fi
            INSTALL_LOCAL_POSTGRES=1;
        ;;
        --local-nginx)
            INSTALL_LOCAL_NGINX=1;
            PROXY_MODE=1;
        ;;
        --domain)
            DOMAIN_NAME=$2;
            shift;
        ;;
        --email)
            SSL_EMAIL=$2;
            shift;
        ;;
        --enable-ssl)
            ENABLE_SSL="yes";
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
odoo_major="";
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
# Asegurar que odoo-helper esté instalado correctamente
#--------------------------------------------------
echo -e "\n${BLUEC}Verificando instalación de odoo-helper-scripts...${NC}";

# Verificar si odoo-helper está instalado y funciona
if ! command -v odoo-helper >/dev/null 2>&1; then
    echo -e "${BLUEC}Odoo-helper no instalado! Instalando...${NC}";
    
    # Descargar instalador con timeout extendido
    if ! wget -q -T 15 -O /tmp/odoo-helper-install.bash \
            https://raw.githubusercontent.com/huntergps/odoo-helper-scripts/master/install-system.bash; then
        echo "${REDC}ERROR${NC}: No se pudo descargar el instalador de odoo-helper-scripts desde github. Verifica tu conexión de red.";
        exit 1;
    fi

    # Instalar odoo-helper-scripts
    echo -e "${BLUEC}Ejecutando instalador de odoo-helper-scripts...${NC}";
    if [ -z "$USE_DEV_VERSION_OF_ODOO_HElPER" ]; then
        bash /tmp/odoo-helper-install.bash master;
    else
        bash /tmp/odoo-helper-install.bash dev;
    fi
    
    # Verificar que la instalación fue exitosa
    if [ ! -f "/etc/odoo-helper.conf" ]; then
        echo -e "${REDC}ERROR${NC}: La instalación de odoo-helper-scripts falló. No se creó /etc/odoo-helper.conf";
        exit 1;
    fi
    
    # Cargar configuración
    source /etc/odoo-helper.conf
    
    # Verificar que las librerías están disponibles
    if [ ! -d "$ODOO_HELPER_LIB" ]; then
        echo -e "${REDC}ERROR${NC}: Directorio de librerías no existe: $ODOO_HELPER_LIB";
        exit 1;
    fi
    
    echo -e "${GREENC}✓${NC} odoo-helper-scripts instalado correctamente";
else
    echo -e "${GREENC}✓${NC} odoo-helper ya está instalado";
fi

# Verificar que la configuración está disponible
if [ ! -f "/etc/odoo-helper.conf" ]; then
    echo -e "${REDC}ERROR${NC}: Archivo de configuración /etc/odoo-helper.conf no encontrado";
    echo -e "${YELLOWC}Reinstalando odoo-helper-scripts...${NC}";
    
    # Limpiar instalación incompleta
    rm -rf /opt/odoo-helper-scripts 2>/dev/null || true
    rm -f /usr/local/bin/odoo-helper* 2>/dev/null || true
    rm -f /etc/odoo-helper.conf 2>/dev/null || true
    
    # Reinstalar
    if ! wget -q -T 15 -O /tmp/odoo-helper-install.bash \
            https://raw.githubusercontent.com/huntergps/odoo-helper-scripts/master/install-system.bash; then
        echo "${REDC}ERROR${NC}: No se pudo descargar el instalador.";
        exit 1;
    fi
    
    bash /tmp/odoo-helper-install.bash master;
    
    # Verificar nuevamente
    if [ ! -f "/etc/odoo-helper.conf" ]; then
        echo -e "${REDC}ERROR CRÍTICO${NC}: No se pudo instalar odoo-helper-scripts correctamente.";
        exit 1;
    fi
fi

# Cargar configuración
source /etc/odoo-helper.conf

# Verificar que las variables están configuradas
if [ -z "$ODOO_HELPER_LIB" ] || [ -z "$ODOO_HELPER_BIN" ]; then
    echo -e "${REDC}ERROR${NC}: Variables de configuración no están definidas en /etc/odoo-helper.conf";
    echo -e "${BLUEC}Contenido del archivo:${NC}";
    cat /etc/odoo-helper.conf
    exit 1;
fi

# Verificar que los directorios existen
if [ ! -d "$ODOO_HELPER_LIB" ]; then
    echo -e "${REDC}ERROR${NC}: Directorio de librerías no existe: $ODOO_HELPER_LIB";
    exit 1;
fi

if [ ! -d "$ODOO_HELPER_BIN" ]; then
    echo -e "${REDC}ERROR${NC}: Directorio de binarios no existe: $ODOO_HELPER_BIN";
    exit 1;
fi

# Verificar que odoo-helper funciona
if ! odoo-helper --version >/dev/null 2>&1; then
    echo -e "${REDC}ERROR${NC}: odoo-helper no funciona correctamente después de la instalación";
    echo -e "${YELLOWC}Verificando instalación...${NC}";
    echo -e "  - Ejecutable: $(which odoo-helper 2>/dev/null || echo 'No encontrado')";
    echo -e "  - Configuración: $ODOO_HELPER_LIB";
    echo -e "  - Binarios: $ODOO_HELPER_BIN";
    exit 1;
fi

echo -e "${GREENC}✓${NC} odoo-helper-scripts verificado y funcionando correctamente";
echo -e "${BLUEC}Versión:${NC} $(odoo-helper --version)";

# La configuración ya está cargada desde la verificación anterior
# Solo mostrar información de estado
echo -e "${BLUEC}Estado de odoo-helper-scripts:${NC}";
echo -e "  • Ejecutable: $(which odoo-helper)";
echo -e "  • Configuración: /etc/odoo-helper.conf";
echo -e "  • Librerías: $ODOO_HELPER_LIB";
echo -e "  • Binarios: $ODOO_HELPER_BIN";

# Instalar pre-requisitos de odoo
echo -e "\n${BLUEC}Instalando pre-requisitos del sistema...${NC}";
sudo odoo-helper install pre-requirements -y;

echo -e "\n${BLUEC}Instalando dependencias específicas para Odoo ${ODOO_VERSION}...${NC}";
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
# Crear Usuario Odoo (movido antes de la instalación)
#--------------------------------------------------
if ! getent passwd $ODOO_USER  > /dev/null; then
    echo -e "\n${BLUEC}Creando usuario Odoo: $ODOO_USER ${NC}\n";
    sudo adduser --system --no-create-home --home $PROJECT_ROOT_DIR \
        --quiet --group $ODOO_USER;
else
    echo -e "\n${YELLOWC}El usuario Odoo ya existe, usando el.${NC}\n";
fi

# Ahora que el usuario existe, podemos cambiar propietarios
sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR/enterprise;

#--------------------------------------------------
# Instalar Odoo
#--------------------------------------------------
echo -e "\n${BLUEC}Instalando odoo...${NC}\n";

# Verificar que odoo-helper funciona correctamente con librerías
echo -e "${BLUEC}Verificando funcionalidad completa de odoo-helper...${NC}";

# Verificar que las librerías de odoo-helper están disponibles
if [ -f "/etc/odoo-helper.conf" ]; then
    source /etc/odoo-helper.conf
    
    # Verificar que las variables del entorno están configuradas
    if [ -z "$ODOO_HELPER_LIB" ]; then
        echo -e "${REDC}ERROR${NC}: ODOO_HELPER_LIB no está configurado en /etc/odoo-helper.conf";
        echo -e "${YELLOWC}Reinstalando odoo-helper-scripts...${NC}";
        
        # Limpiar instalación corrupta
        rm -rf /opt/odoo-helper-scripts 2>/dev/null || true
        rm -f /usr/local/bin/odoo-helper* 2>/dev/null || true
        rm -f /etc/odoo-helper.conf 2>/dev/null || true
        
        # Reinstalar completamente
        wget -q -T 15 -O /tmp/odoo-helper-install.bash \
            https://raw.githubusercontent.com/huntergps/odoo-helper-scripts/master/install-system.bash;
        sudo bash /tmp/odoo-helper-install.bash master;
        
        # Verificar nuevamente
        if [ -f "/etc/odoo-helper.conf" ]; then
            source /etc/odoo-helper.conf
        fi
        
        if [ -z "$ODOO_HELPER_LIB" ]; then
            echo -e "${REDC}ERROR CRÍTICO${NC}: No se pudo configurar odoo-helper correctamente.";
            exit 1;
        fi
    fi
    
    # Verificar que el directorio de librerías existe
    if [ ! -d "$ODOO_HELPER_LIB" ]; then
        echo -e "${REDC}ERROR${NC}: Directorio de librerías no existe: $ODOO_HELPER_LIB";
        exit 1;
    fi
    
    # Verificar que el archivo común existe
    if [ ! -f "$ODOO_HELPER_LIB/common.bash" ]; then
        echo -e "${REDC}ERROR${NC}: Archivo de librerías común no existe: $ODOO_HELPER_LIB/common.bash";
        exit 1;
    fi
    
    echo -e "${GREENC}✓${NC} Librerías de odoo-helper verificadas en: $ODOO_HELPER_LIB";
else
    echo -e "${REDC}ERROR${NC}: No se encontró /etc/odoo-helper.conf";
    exit 1;
fi

# Ahora importar las librerías usando la ruta verificada
echo -e "${BLUEC}Importando librerías de odoo-helper...${NC}";
source "$ODOO_HELPER_LIB/common.bash";

# importar bibliotecas de odoo-helper
ohelper_require 'install';
ohelper_require 'config';

# No preguntar confirmación al instalar dependencias
ALWAYS_ANSWER_YES=1;

# Configurar variables por defecto de odoo-helper
config_set_defaults;  # importado desde el módulo común

# definir ruta de complementos a colocar en los archivos de configuración
# Modernizado para Odoo 18.3 - Crear directorio enterprise y actualizar paths
sudo mkdir -p $PROJECT_ROOT_DIR/enterprise;
# Nota: chown se hará después de crear el usuario odoo

# Paths modernizados - se elimina openerp/addons (muy antiguo)
ADDONS_PATH="$ODOO_PATH/addons,$PROJECT_ROOT_DIR/enterprise,$ODOO_PATH/odoo/addons,$ADDONS_DIR";
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
echo -e "\n${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
echo -e "${BLUEC}                    INICIANDO INSTALACIÓN DE ODOO                    ${NC}";
echo -e "${BLUEC}═══════════════════════════════════════════════════════════════${NC}";

if ! install_odoo_install; then  # importado desde el módulo 'install'
    echo -e "\n${REDC}═══════════════════════════════════════════════════════════════${NC}";
    echo -e "${REDC}                ERROR CRÍTICO EN INSTALACIÓN                    ${NC}";
    echo -e "${REDC}═══════════════════════════════════════════════════════════════${NC}";
    echo -e "${REDC}La instalación de Odoo falló. Revisa los mensajes de error anteriores.${NC}";
    echo -e "${YELLOWC}Los archivos temporales y configuraciones parciales pueden haber quedado en el sistema.${NC}";
    echo -e "${REDC}ABORTANDO INSTALACIÓN COMPLETA DEL SERVIDOR${NC}";
    exit 1;
fi

#--------------------------------------------------
# CORRECCIÓN AUTOMÁTICA DE DEPENDENCIAS PYTHON PARA ODOO 18.3
#--------------------------------------------------
echo -e "\n${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
echo -e "${BLUEC}           CORRIGIENDO DEPENDENCIAS PYTHON                        ${NC}";
echo -e "${BLUEC}═══════════════════════════════════════════════════════════════${NC}";

# Activar entorno virtual
echo -e "${BLUEC}Activando entorno virtual...${NC}";
source $VENV_DIR/bin/activate;

# Corregir pyOpenSSL para Python 3.10
echo -e "${BLUEC}Corrigiendo pyOpenSSL para Python 3.10...${NC}";
sudo $VENV_DIR/bin/pip uninstall -y pyOpenSSL;
sudo $VENV_DIR/bin/pip install pyOpenSSL==21.0.0;

# Verificar que la corrección funcionó
if $VENV_DIR/bin/python3 -c "import OpenSSL; print('pyOpenSSL version:', OpenSSL.__version__)" 2>/dev/null; then
    echo -e "${GREENC}✓${NC} pyOpenSSL corregido exitosamente";
else
    echo -e "${REDC}✗${NC} Error al corregir pyOpenSSL";
    echo -e "${YELLOWC}Continuando con instalación...${NC}";
fi

# Corregir permisos del entorno virtual
echo -e "${BLUEC}Corrigiendo permisos del entorno virtual...${NC}";
sudo chmod -R a+rwX $VENV_DIR;

echo -e "${GREENC}✓${NC} Dependencias de Python corregidas para Odoo 18.3";

# generar archivo de configuración de odoo modernizado para Odoo 18.3
echo -e "\n${BLUEC}Generando archivo de configuración optimizado para Odoo 18.3...${NC}\n";

# Crear archivo de configuración manual con opciones optimizadas
sudo cat > $ODOO_CONF_FILE << EOF
[options]
# Configuración básica
addons_path = $ADDONS_PATH
data_dir = $DATA_DIR
admin_passwd = $(random_string 32)

# Base de datos
db_host = $DB_HOST
db_port = False
db_user = $DB_USER
db_password = $DB_PASSWORD
db_maxconn = 64

# Servidor HTTP
http_enable = True
http_port = 8069
gevent_port = 8072

# Workers para producción
workers = $ODOO_WORKERS
max_cron_threads = 2

# Logging
logfile = $LOG_FILE
log_level = info
log_db = False
log_handler = :INFO

# Seguridad
list_db = False
EOF

# Agregar configuraciones específicas según el modo
if [ ! -z $PROXY_MODE ]; then
    echo "proxy_mode = True" >> $ODOO_CONF_FILE;
    echo "# X-Sendfile deshabilitado inicialmente - habilitar tras configurar Nginx" >> $ODOO_CONF_FILE;
    echo "x_sendfile = False" >> $ODOO_CONF_FILE;
else
    echo "proxy_mode = False" >> $ODOO_CONF_FILE;
    echo "x_sendfile = False" >> $ODOO_CONF_FILE;
fi

# Agregar configuraciones adicionales para optimización
cat >> $ODOO_CONF_FILE << EOF

# Optimizaciones de memoria y rendimiento
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
limit_time_real_cron = 300

# Configuración de archivos estáticos
static_http_enable = True
static_http_document_root = None

# Configuración de email (personalizar según necesidades)
email_from = False
smtp_server = localhost
smtp_port = 25
smtp_ssl = False
smtp_user = False
smtp_password = False

# Configuración de desarrollador (deshabilitado en producción)
dev_mode = False
test_enable = False
without_demo = True

# El archivo PID será manejado por systemd
pidfile = None
EOF

echo -e "${GREENC}✓${NC} Archivo de configuración creado: $ODOO_CONF_FILE";

# Escribir configuración del proyecto de odoo-helper
echo "#---ODOO-INSTANCE-CONFIG---" >> /etc/$CONF_FILE_NAME;
echo "`config_print`" >> /etc/$CONF_FILE_NAME;

# esto hará que los scripts de odoo-helper ejecuten odoo con el usuario especificado
# (a través de una llamada sudo)
echo "SERVER_RUN_USER=$ODOO_USER;" >> /etc/$CONF_FILE_NAME;

#--------------------------------------------------
# Verificar estructura de directorios modernizada para Odoo 18.3
#--------------------------------------------------
if [ ! -d $ODOO_PATH/odoo/addons ]; then
    sudo mkdir -p $ODOO_PATH/odoo/addons;
fi

# Verificar que el directorio enterprise fue creado correctamente
if [ ! -d $PROJECT_ROOT_DIR/enterprise ]; then
    sudo mkdir -p $PROJECT_ROOT_DIR/enterprise;
    sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR/enterprise;
fi

echo -e "${GREENC}✓${NC} Estructura de directorios de addons modernizada para Odoo 18.3";



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

#--------------------------------------------------
# CORRECCIÓN FINAL DE PERMISOS
#--------------------------------------------------
echo -e "\n${BLUEC}Aplicando correcciones finales de permisos...${NC}";

# Permisos del entorno virtual
sudo chmod -R a+rwX $VENV_DIR;

# Permisos de directorios críticos
sudo chown -R $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR;
sudo chmod 750 $LOG_DIR;
sudo chmod 750 $DATA_DIR;
sudo chmod 755 $ADDONS_DIR;

echo -e "${GREENC}✓${NC} Permisos corregidos";

echo -e "\n${GREENC}Odoo instalado!${NC}\n";

#--------------------------------------------------
# Configuración avanzada de Nginx con SSL
#--------------------------------------------------
if [ ! -z $INSTALL_LOCAL_NGINX ]; then
    echo -e "\n${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
    echo -e "${BLUEC}           CONFIGURANDO NGINX CON SSL AUTOMÁTICO                  ${NC}";
    echo -e "${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
    
    # Instalar Nginx y Certbot
    echo -e "${BLUEC}Instalando Nginx y Certbot...${NC}";
    sudo apt-get install -qqq -y --no-install-recommends nginx certbot python3-certbot-nginx;
    
    # Determinar nombre del servidor
    if [ ! -z "$DOMAIN_NAME" ]; then
        SERVER_NAME="$DOMAIN_NAME";
        CONF_NAME="$DOMAIN_NAME";
    else
        SERVER_NAME="$(hostname)";
        CONF_NAME="$(hostname -s)";
    fi
    
    NGINX_CONF_PATH="/etc/nginx/sites-available/$CONF_NAME.conf";
    
    echo -e "${BLUEC}Generando configuración de Nginx para: ${YELLOWC}$SERVER_NAME${NC}";
    
    # Crear configuración inicial de Nginx optimizada para Odoo 18.3
    sudo cat > $NGINX_CONF_PATH << EOF
# Configuración optimizada para Odoo 18.3 con soporte X-Sendfile
upstream crnd_odoo {
    server 127.0.0.1:8069 weight=1 fail_timeout=300s;
    keepalive 32;
}

upstream crnd_odoo_longpolling {
    server 127.0.0.1:8072 weight=1 fail_timeout=300s;
}

# Configuración del mapa de actualización para WebSocket
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name $SERVER_NAME;
    
    # Logs
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;
    
    # Configuración básica de rendimiento
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    
    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Configuración principal de Odoo
    location / {
        proxy_pass http://crnd_odoo;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        
        # Headers básicos
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Buffer sizes optimizados
        proxy_buffers 16 64k;
        proxy_buffer_size 128k;
        proxy_busy_buffers_size 256k;
        proxy_temp_file_write_size 256k;
        
        # Timeouts optimizados
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Configuración de cache y buffering
        proxy_buffering on;
        proxy_redirect off;
        
        # Client settings
        client_max_body_size 200m;
        client_body_timeout 300s;
        
        # Keep-alive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
    
    # Longpolling para chat y notificaciones
    location /longpolling {
        proxy_pass http://crnd_odoo_longpolling;
        
        # Headers para WebSocket
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        
        # Timeouts para conexiones largas
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 600s;
        
        # Sin buffering para tiempo real
        proxy_buffering off;
        
        # Keep-alive para WebSocket
        proxy_http_version 1.1;
    }
    
    # Cache agresivo para archivos estáticos
    location /web/static/ {
        proxy_pass http://crnd_odoo;
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404 1m;
        proxy_buffering on;
        
        # Headers de cache
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Cache-Status \$upstream_cache_status;
        
        # Compresión
        gzip on;
        gzip_vary on;
        gzip_types text/css application/javascript image/svg+xml;
    }
    
    # Manejo de reportes y archivos grandes
    location ~* ^/web/content/.*\.(pdf|xlsx|docx|zip)$ {
        proxy_pass http://crnd_odoo;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 500m;
        
        # Timeouts extendidos para archivos grandes
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }
    
    # Restricciones de seguridad
    location ~* ^/(web/database/|xmlrpc|jsonrpc) {
        # TODO: Restringir acceso desde IPs confiables en producción
        # allow 192.168.0.0/16;
        # allow 10.0.0.0/8;
        # deny all;
        
        proxy_pass http://crnd_odoo;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Bloquear acceso a archivos sensibles
    location ~* \.(log|conf|ini)$ {
        deny all;
        return 404;
    }
}
EOF
    
    # Habilitar sitio
    sudo ln -sf $NGINX_CONF_PATH /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Probar configuración
    if ! sudo nginx -t; then
        echo -e "${REDC}ERROR${NC}: Configuración de Nginx inválida";
        exit 1;
    fi
    
    # Reiniciar Nginx
    sudo systemctl restart nginx;
    sudo systemctl enable nginx;
    
    echo -e "${GREENC}✓${NC} Nginx configurado correctamente";
    
    #--------------------------------------------------
    # Configurar SSL con Let's Encrypt
    #--------------------------------------------------
    if [ "$ENABLE_SSL" == "yes" ] && [ ! -z "$DOMAIN_NAME" ] && [ ! -z "$SSL_EMAIL" ]; then
        echo -e "\n${BLUEC}Configurando SSL con Let's Encrypt...${NC}";
        
        # Crear directorio para verificación
        sudo mkdir -p /var/www/html/.well-known/acme-challenge/
        
        # Obtener certificado SSL
        echo -e "${BLUEC}Solicitando certificado SSL para: ${YELLOWC}$DOMAIN_NAME${NC}";
        if sudo certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect; then
            echo -e "${GREENC}✓${NC} Certificado SSL instalado correctamente";
            
            # Habilitar X-Sendfile en Odoo tras configurar SSL
            echo -e "${BLUEC}Habilitando X-Sendfile en configuración de Odoo...${NC}";
            sudo sed -i 's/x_sendfile = False/x_sendfile = True/' $ODOO_CONF_FILE;
            
            # Agregar comentario explicativo
            sudo sed -i '/x_sendfile = True/a # X-Sendfile habilitado - Nginx configurado con sendfile on' $ODOO_CONF_FILE;
            
            # Configurar renovación automática
            echo -e "${BLUEC}Configurando renovación automática de SSL...${NC}";
            sudo systemctl enable certbot.timer;
            sudo systemctl start certbot.timer;
            
            echo -e "${GREENC}✓${NC} Renovación automática de SSL configurada";
            echo -e "${GREENC}✓${NC} X-Sendfile habilitado para mejor rendimiento";
        else
            echo -e "${YELLOWC}ADVERTENCIA${NC}: No se pudo obtener el certificado SSL";
            echo -e "${YELLOWC}Verifica que:${NC}";
            echo -e "  • El dominio $DOMAIN_NAME apunte a esta IP";
            echo -e "  • Los puertos 80 y 443 estén abiertos";
            echo -e "  • No haya firewalls bloqueando el tráfico";
        fi
    else
        echo -e "\n${YELLOWC}NOTA${NC}: SSL no configurado. Para habilitarlo usa:";
        echo -e "${BLUEC}--domain tu-dominio.com --email tu@email.com --enable-ssl${NC}";
    fi
    
    echo -e "\n${GREENC}════════════════════════════════════════════════════════════════${NC}";
    echo -e "${GREENC}                   NGINX CONFIGURADO EXITOSAMENTE                   ${NC}";
    echo -e "${GREENC}════════════════════════════════════════════════════════════════${NC}";
    echo -e "${BLUEC}Configuración ubicada en:${NC} $NGINX_CONF_PATH";
    if [ ! -z "$DOMAIN_NAME" ]; then
        if [ "$ENABLE_SSL" == "yes" ]; then
            echo -e "${BLUEC}Acceso web:${NC} https://$DOMAIN_NAME";
        else
            echo -e "${BLUEC}Acceso web:${NC} http://$DOMAIN_NAME";
        fi
    else
        echo -e "${BLUEC}Acceso web:${NC} http://$(hostname)";
    fi
fi

#--------------------------------------------------
# Crear servicio systemd moderno
#--------------------------------------------------
echo -e "\n${BLUEC}Configurando servicio systemd...${NC}";

# Crear archivo de servicio systemd
sudo cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo SaaS 18.3
Documentation=https://www.odoo.com
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$VENV_DIR/bin/python3 $ODOO_PATH/odoo-bin -c $ODOO_CONF_FILE
WorkingDirectory=$PROJECT_ROOT_DIR
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=odoo
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=30
Restart=on-failure
RestartSec=5

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=$DATA_DIR $LOG_DIR /tmp

# Environment
Environment=PATH=$VENV_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar servicio
sudo systemctl daemon-reload;
sudo systemctl enable odoo.service;

echo -e "${GREENC}✓${NC} Servicio systemd configurado y habilitado";

#--------------------------------------------------
# Resumen final de instalación
#--------------------------------------------------
echo -e "\n${GREENC}════════════════════════════════════════════════════════════════${NC}";
echo -e "${GREENC}              INSTALACIÓN COMPLETADA EXITOSAMENTE                  ${NC}";
echo -e "${GREENC}════════════════════════════════════════════════════════════════${NC}";
echo -e "${BLUEC}Odoo instalado en:${NC} $PROJECT_ROOT_DIR";
echo -e "${BLUEC}Usuario Odoo:${NC} $ODOO_USER";
echo -e "${BLUEC}Base de datos:${NC} PostgreSQL (Usuario: $DB_USER)";
echo -e "${BLUEC}Archivo de configuración:${NC} $ODOO_CONF_FILE";
echo -e "${BLUEC}Logs:${NC} $LOG_FILE";
echo -e "${BLUEC}Workers configurados:${NC} $ODOO_WORKERS";

if [ ! -z "$DOMAIN_NAME" ]; then
    if [ "$ENABLE_SSL" == "yes" ]; then
        echo -e "${BLUEC}URL de acceso:${NC} https://$DOMAIN_NAME";
    else
        echo -e "${BLUEC}URL de acceso:${NC} http://$DOMAIN_NAME";
    fi
else
    echo -e "${BLUEC}URL de acceso:${NC} http://$(hostname)";
fi

echo -e "\n${BLUEC}Comandos útiles:${NC}";
echo -e "  • Iniciar Odoo: ${YELLOWC}sudo systemctl start odoo${NC}";
echo -e "  • Detener Odoo: ${YELLOWC}sudo systemctl stop odoo${NC}";
echo -e "  • Reiniciar Odoo: ${YELLOWC}sudo systemctl restart odoo${NC}";
echo -e "  • Ver estado: ${YELLOWC}sudo systemctl status odoo${NC}";
echo -e "  • Ver logs: ${YELLOWC}sudo journalctl -u odoo -f${NC}";

echo -e "\n${GREENC}¡Instalación lista para producción!${NC}\n";


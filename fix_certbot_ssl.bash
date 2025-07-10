#!/bin/bash

# Script para diagnosticar y corregir problemas de SSL/certbot
# Uso: ./fix_certbot_ssl.bash [dominio] [email]

# Colores para output
REDC='\e[31m'
GREENC='\e[32m'
YELLOWC='\e[33m'
BLUEC='\e[34m'
NC='\e[0m'

DOMAIN_NAME="$1"
SSL_EMAIL="$2"

if [ -z "$DOMAIN_NAME" ] || [ -z "$SSL_EMAIL" ]; then
    echo -e "${REDC}Error:${NC} Uso: $0 [dominio] [email]"
    echo -e "Ejemplo: $0 erp1.tecnosmart.com.ec admin@tecnosmart.com.ec"
    exit 1
fi

echo -e "${BLUEC}🔧 Diagnóstico y Corrección de SSL/Certbot${NC}"
echo -e "${BLUEC}═══════════════════════════════════════════${NC}"

# 1. Verificar Python y dependencias
echo -e "\n${BLUEC}1. Verificando Python y dependencias...${NC}"

# Verificar Python del sistema
if command -v python3 >/dev/null 2>&1; then
    echo -e "  ${GREENC}✓${NC} Python3 encontrado: $(python3 --version)"
else
    echo -e "  ${REDC}✗${NC} Python3 no encontrado"
    exit 1
fi

# Verificar pyOpenSSL en sistema
if python3 -c "import OpenSSL; print('pyOpenSSL version:', OpenSSL.__version__)" 2>/dev/null; then
    echo -e "  ${GREENC}✓${NC} pyOpenSSL disponible en sistema"
else
    echo -e "  ${YELLOWC}⚠${NC} pyOpenSSL no disponible en sistema"
    echo -e "  ${BLUEC}Instalando pyOpenSSL...${NC}"
    
    # Instalar paquetes del sistema
    sudo apt-get update -qq
    sudo apt-get install -y python3-openssl python3-cryptography python3-pip
    
    # Verificar si funcionó
    if python3 -c "import OpenSSL" 2>/dev/null; then
        echo -e "  ${GREENC}✓${NC} pyOpenSSL instalado exitosamente"
    else
        echo -e "  ${YELLOWC}⚠${NC} Intentando con pip..."
        sudo python3 -m pip install pyOpenSSL==21.0.0 cryptography --break-system-packages
        
        if python3 -c "import OpenSSL" 2>/dev/null; then
            echo -e "  ${GREENC}✓${NC} pyOpenSSL instalado vía pip"
        else
            echo -e "  ${REDC}✗${NC} No se pudo instalar pyOpenSSL"
            exit 1
        fi
    fi
fi

# 2. Verificar certbot
echo -e "\n${BLUEC}2. Verificando certbot...${NC}"

if command -v certbot >/dev/null 2>&1; then
    echo -e "  ${GREENC}✓${NC} Certbot encontrado"
    
    # Verificar que certbot funciona
    if certbot --version >/dev/null 2>&1; then
        echo -e "  ${GREENC}✓${NC} Certbot funcional: $(certbot --version 2>&1)"
    else
        echo -e "  ${REDC}✗${NC} Certbot no funcional, reinstalando..."
        sudo apt-get remove -y certbot python3-certbot-nginx
        sudo apt-get install -y certbot python3-certbot-nginx
        
        if certbot --version >/dev/null 2>&1; then
            echo -e "  ${GREENC}✓${NC} Certbot reinstalado exitosamente"
        else
            echo -e "  ${REDC}✗${NC} No se pudo reparar certbot"
            exit 1
        fi
    fi
else
    echo -e "  ${REDC}✗${NC} Certbot no encontrado, instalando..."
    sudo apt-get update -qq
    sudo apt-get install -y certbot python3-certbot-nginx
    
    if command -v certbot >/dev/null 2>&1; then
        echo -e "  ${GREENC}✓${NC} Certbot instalado exitosamente"
    else
        echo -e "  ${REDC}✗${NC} No se pudo instalar certbot"
        exit 1
    fi
fi

# 3. Verificar Nginx
echo -e "\n${BLUEC}3. Verificando Nginx...${NC}"

if command -v nginx >/dev/null 2>&1; then
    echo -e "  ${GREENC}✓${NC} Nginx encontrado"
    
    # Verificar configuración
    if sudo nginx -t >/dev/null 2>&1; then
        echo -e "  ${GREENC}✓${NC} Configuración de Nginx válida"
    else
        echo -e "  ${REDC}✗${NC} Configuración de Nginx inválida"
        sudo nginx -t
        exit 1
    fi
    
    # Verificar estado del servicio
    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREENC}✓${NC} Nginx activo"
    else
        echo -e "  ${YELLOWC}⚠${NC} Nginx inactivo, iniciando..."
        sudo systemctl start nginx
        sudo systemctl enable nginx
        
        if systemctl is-active --quiet nginx; then
            echo -e "  ${GREENC}✓${NC} Nginx iniciado exitosamente"
        else
            echo -e "  ${REDC}✗${NC} No se pudo iniciar Nginx"
            exit 1
        fi
    fi
else
    echo -e "  ${REDC}✗${NC} Nginx no encontrado"
    exit 1
fi

# 4. Verificar conectividad del dominio
echo -e "\n${BLUEC}4. Verificando conectividad del dominio...${NC}"

# Verificar resolución DNS
if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
    echo -e "  ${GREENC}✓${NC} Dominio $DOMAIN_NAME resuelve correctamente"
    
    # Mostrar IP del dominio
    DOMAIN_IP=$(nslookup "$DOMAIN_NAME" | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo -e "  ${BLUEC}IP del dominio:${NC} $DOMAIN_IP"
    
    # Mostrar IP del servidor
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "No disponible")
    echo -e "  ${BLUEC}IP del servidor:${NC} $SERVER_IP"
    
    if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        echo -e "  ${GREENC}✓${NC} El dominio apunta a este servidor"
    else
        echo -e "  ${YELLOWC}⚠${NC} El dominio NO apunta a este servidor"
        echo -e "  ${YELLOWC}Asegúrate de que el DNS esté configurado correctamente${NC}"
    fi
else
    echo -e "  ${REDC}✗${NC} No se puede resolver el dominio $DOMAIN_NAME"
    echo -e "  ${YELLOWC}Verifica que el dominio esté configurado correctamente${NC}"
fi

# Verificar puertos
echo -e "\n${BLUEC}5. Verificando puertos...${NC}"

# Puerto 80
if netstat -tuln | grep -q ":80 "; then
    echo -e "  ${GREENC}✓${NC} Puerto 80 abierto"
else
    echo -e "  ${REDC}✗${NC} Puerto 80 no disponible"
fi

# Puerto 443
if netstat -tuln | grep -q ":443 "; then
    echo -e "  ${GREENC}✓${NC} Puerto 443 abierto"
else
    echo -e "  ${YELLOWC}⚠${NC} Puerto 443 no disponible (normal antes de SSL)"
fi

# 6. Intentar obtener certificado SSL
echo -e "\n${BLUEC}6. Intentando obtener certificado SSL...${NC}"

# Crear directorio para verificación
sudo mkdir -p /var/www/html/.well-known/acme-challenge/

echo -e "${BLUEC}Ejecutando certbot para $DOMAIN_NAME...${NC}"
echo -e "${BLUEC}Comando: sudo certbot --nginx -d $DOMAIN_NAME --email $SSL_EMAIL --agree-tos --non-interactive --redirect${NC}"

if sudo certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect; then
    echo -e "\n${GREENC}🎉 ¡Certificado SSL obtenido exitosamente!${NC}"
    
    # Configurar renovación automática
    echo -e "${BLUEC}Configurando renovación automática...${NC}"
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    
    echo -e "${GREENC}✓${NC} Renovación automática configurada"
    echo -e "${GREENC}✓${NC} Tu sitio está disponible en: https://$DOMAIN_NAME"
    
    # Verificar certificado
    echo -e "\n${BLUEC}Verificando certificado...${NC}"
    if sudo certbot certificates | grep -q "$DOMAIN_NAME"; then
        echo -e "${GREENC}✓${NC} Certificado verificado correctamente"
    fi
    
else
    echo -e "\n${REDC}❌ No se pudo obtener el certificado SSL${NC}"
    echo -e "${YELLOWC}Posibles causas:${NC}"
    echo -e "  • El dominio no apunta a este servidor"
    echo -e "  • Firewall bloqueando puertos 80/443"
    echo -e "  • Nginx no configurado correctamente"
    echo -e "  • Límites de rate limiting de Let's Encrypt"
    
    echo -e "\n${BLUEC}Logs de certbot:${NC}"
    sudo tail -20 /var/log/letsencrypt/letsencrypt.log 2>/dev/null || echo "No hay logs disponibles"
    
    exit 1
fi

echo -e "\n${GREENC}🎉 ¡Configuración SSL completada exitosamente!${NC}" 
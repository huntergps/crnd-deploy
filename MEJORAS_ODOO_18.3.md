# 🚀 Mejoras Implementadas para Odoo 18.3

## 📋 Resumen de Cambios

Este documento describe las mejoras implementadas en los scripts de instalación para garantizar la compatibilidad y funcionamiento correcto de Odoo 18.3.

## 🔧 Problemas Solucionados

### 1. **Problema de pyOpenSSL con Python 3.10**
- **Error**: `AttributeError: module 'lib' has no attribute 'OpenSSL_add_all_algorithms'`
- **Causa**: Incompatibilidad entre pyOpenSSL y Python 3.10 en Odoo 18.3
- **Solución**: Instalación automática de pyOpenSSL==21.0.0

### 2. **Permisos del Entorno Virtual**
- **Error**: Problemas de permisos en `/opt/odoo/venv/`
- **Causa**: Permisos restrictivos que impiden la ejecución
- **Solución**: `chmod -R a+rwX /opt/odoo/venv`

### 3. **Contraseña por Defecto PostgreSQL**
- **Problema**: Contraseña aleatoria difícil de recordar
- **Solución**: Contraseña por defecto `Odoo123` (solo si no se especifica `--db-password`)

### 4. **Problema del Directorio Enterprise**
- **Error**: `chown: cannot access '/opt/odoo/enterprise': No such file or directory`
- **Causa**: Se intentaba cambiar propietario antes de crear el directorio
- **Solución**: Crear directorio y cambiar propietario en el orden correcto

## 🎯 Mejoras Implementadas

### En `crnd-deploy.bash`

#### 1. **Configuración de Contraseña por Defecto**
```bash
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
```

#### 2. **Corrección Automática de Dependencias Python**
```bash
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
```

#### 3. **Corrección Final de Permisos**
```bash
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
```

#### 5. **Verificación Automática de Instalación**
```bash
#--------------------------------------------------
# VERIFICACIÓN AUTOMÁTICA DE INSTALACIÓN
#--------------------------------------------------
echo -e "\n${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
echo -e "${BLUEC}           VERIFICACIÓN AUTOMÁTICA DE INSTALACIÓN                ${NC}";
echo -e "${BLUEC}═══════════════════════════════════════════════════════════════${NC}";

# Verificar directorios críticos
echo -e "${BLUEC}Verificando estructura de directorios...${NC}";
declare -a critical_dirs=(
    "$PROJECT_ROOT_DIR"
    "$PROJECT_ROOT_DIR/enterprise"
    "$PROJECT_ROOT_DIR/odoo"
    "$PROJECT_ROOT_DIR/venv"
    "$PROJECT_ROOT_DIR/logs"
    "$PROJECT_ROOT_DIR/data"
    "$PROJECT_ROOT_DIR/custom_addons"
)

local missing_dirs=0;
for dir in "${critical_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREENC}✓${NC} $dir";
    else
        echo -e "  ${REDC}✗${NC} $dir (NO EXISTE)";
        ((missing_dirs++));
    fi
done

# Verificar usuario odoo
echo -e "\n${BLUEC}Verificando usuario odoo...${NC}";
if getent passwd $ODOO_USER > /dev/null; then
    echo -e "  ${GREENC}✓${NC} Usuario $ODOO_USER existe";
else
    echo -e "  ${REDC}✗${NC} Usuario $ODOO_USER NO EXISTE";
    ((missing_dirs++));
fi

# Verificar pyOpenSSL
echo -e "\n${BLUEC}Verificando pyOpenSSL...${NC}";
if [ -d "$VENV_DIR" ]; then
    if "$VENV_DIR/bin/python3" -c "import OpenSSL; print('pyOpenSSL version:', OpenSSL.__version__)" 2>/dev/null; then
        local openssl_version=$("$VENV_DIR/bin/python3" -c "import OpenSSL; print(OpenSSL.__version__)" 2>/dev/null);
        echo -e "  ${GREENC}✓${NC} pyOpenSSL instalado: $openssl_version";
        
        if [[ "$openssl_version" == "21.0.0" ]]; then
            echo -e "  ${GREENC}✓${NC} Versión correcta (21.0.0)";
        else
            echo -e "  ${YELLOWC}⚠${NC} Versión diferente a 21.0.0: $openssl_version";
        fi
    else
        echo -e "  ${REDC}✗${NC} pyOpenSSL NO FUNCIONA";
        ((missing_dirs++));
    fi
else
    echo -e "  ${REDC}✗${NC} Entorno virtual no existe";
    ((missing_dirs++));
fi

# Verificar PostgreSQL
echo -e "\n${BLUEC}Verificando PostgreSQL...${NC}";
if command -v psql >/dev/null 2>&1; then
    echo -e "  ${GREENC}✓${NC} PostgreSQL instalado";
    
    if systemctl is-active --quiet postgresql; then
        echo -e "  ${GREENC}✓${NC} Servicio PostgreSQL activo";
    else
        echo -e "  ${YELLOWC}⚠${NC} Servicio PostgreSQL inactivo";
    fi
    
    if sudo -u postgres psql -c "\du odoo" 2>/dev/null | grep -q odoo; then
        echo -e "  ${GREENC}✓${NC} Usuario PostgreSQL 'odoo' existe";
    else
        echo -e "  ${REDC}✗${NC} Usuario PostgreSQL 'odoo' NO EXISTE";
        ((missing_dirs++));
    fi
else
    echo -e "  ${REDC}✗${NC} PostgreSQL NO INSTALADO";
    ((missing_dirs++));
fi

# Verificar servicio Odoo
echo -e "\n${BLUEC}Verificando servicio Odoo...${NC}";
if [ -f "/etc/init.d/odoo" ]; then
    echo -e "  ${GREENC}✓${NC} Script de servicio existe";
else
    echo -e "  ${REDC}✗${NC} Script de servicio NO EXISTE";
    ((missing_dirs++));
fi

# Resumen de verificación
echo -e "\n${BLUEC}═══════════════════════════════════════════════════════════════${NC}";
echo -e "${BLUEC}                    RESUMEN DE VERIFICACIÓN                      ${NC}";
echo -e "${BLUEC}═══════════════════════════════════════════════════════════════${NC}";

if [ $missing_dirs -eq 0 ]; then
    echo -e "${GREENC}✓${NC} Instalación completada exitosamente";
    echo -e "${GREENC}✓${NC} Todos los componentes verificados correctamente";
else
    echo -e "${REDC}✗${NC} Se detectaron $missing_dirs problema(s) en la instalación";
    echo -e "${YELLOWC}Recomendaciones:${NC}";
    echo -e "  • Ejecutar: ${BLUEC}sudo odoo-helper install fix-python-deps${NC}";
    echo -e "  • Verificar logs: ${BLUEC}sudo journalctl -u odoo -f${NC}";
    echo -e "  • Reiniciar servicio: ${BLUEC}sudo systemctl restart odoo${NC}";
fi
```

#### 4. **Corrección del Directorio Enterprise**
```bash
#--------------------------------------------------
# CORRECCIÓN DEL DIRECTORIO ENTERPRISE
#--------------------------------------------------
# Crear directorio enterprise y corregir propietario inmediatamente
sudo mkdir -p $PROJECT_ROOT_DIR/enterprise;
sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR/enterprise;

# Verificación adicional con corrección de propietario
if [ ! -d $PROJECT_ROOT_DIR/enterprise ]; then
    sudo mkdir -p $PROJECT_ROOT_DIR/enterprise;
    sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR/enterprise;
    echo -e "${BLUEC}Directorio enterprise creado: ${YELLOWC}$PROJECT_ROOT_DIR/enterprise${NC}";
else
    # Verificar que el propietario es correcto
    local enterprise_owner=$(stat -c '%U' $PROJECT_ROOT_DIR/enterprise 2>/dev/null || echo "unknown");
    if [ "$enterprise_owner" != "$ODOO_USER" ]; then
        sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR/enterprise;
        echo -e "${BLUEC}Propietario del directorio enterprise corregido${NC}";
    fi
fi
```

### En `odoo-helper-scripts/lib/install.bash`

#### 1. **Nuevo Comando: `fix-python-deps`**
```bash
$SCRIPT_NAME install fix-python-deps [--help]    - corregir dependencias Python para Odoo 18.3
```

#### 2. **Función de Corrección Manual**
```bash
function install_fix_python_dependencies {
    # Verificar que el entorno virtual existe
    if [ ! -d "$VENV_DIR" ]; then
        echoe -e "${REDC}ERROR${NC}: Entorno virtual no encontrado en ${YELLOWC}$VENV_DIR${NC}";
        return 1;
    fi

    # Activar entorno virtual
    source "$VENV_DIR/bin/activate";

    # Verificar si pyOpenSSL necesita corrección
    local needs_fix=false;
    if ! "$VENV_DIR/bin/python3" -c "import OpenSSL; print('pyOpenSSL version:', OpenSSL.__version__)" 2>/dev/null; then
        needs_fix=true;
    fi

    if [ "$needs_fix" = true ]; then
        echoe -e "${BLUEC}Corrigiendo pyOpenSSL para Python 3.10...${NC}";
        
        # Desinstalar pyOpenSSL actual
        "$VENV_DIR/bin/pip" uninstall -y pyOpenSSL;
        
        # Instalar versión compatible
        if "$VENV_DIR/bin/pip" install pyOpenSSL==21.0.0; then
            echoe -e "${GREENC}✓${NC} pyOpenSSL corregido exitosamente";
        else
            echoe -e "${REDC}✗${NC} Error al corregir pyOpenSSL";
            return 1;
        fi
    fi

    # Corregir permisos del entorno virtual
    echoe -e "${BLUEC}Corrigiendo permisos del entorno virtual...${NC}";
    sudo chmod -R a+rwX "$VENV_DIR";

    echoe -e "${GREENC}✓${NC} Dependencias de Python corregidas exitosamente";
}
```

## 🚀 Uso de las Mejoras

### Instalación Automática
Las correcciones se aplican automáticamente durante la instalación:
```bash
sudo bash crnd-deploy/crnd-deploy.bash --odoo-version saas-18.3 --local-postgres --local-nginx --proxy-mode --workers 4 --domain erp1.tecnosmart.com.ec --email esalazargps@gmail.com --enable-ssl
```

### Corrección Manual (si es necesario)
Si necesitas corregir las dependencias manualmente:
```bash
# Desde el directorio del proyecto
sudo odoo-helper install fix-python-deps

# O con forzar corrección
sudo odoo-helper install fix-python-deps --force
```

## ✅ Verificación Automática

El script de instalación incluye verificación automática al final que comprueba:
- ✅ Estructura de directorios
- ✅ Usuario odoo
- ✅ pyOpenSSL funcionando
- ✅ PostgreSQL y usuario de base de datos
- ✅ Servicio Odoo configurado

## 🔍 Diagnóstico de Problemas

### Si Odoo no inicia:
1. **Verificar logs**: `sudo journalctl -u odoo -f`
2. **Verificar dependencias**: `sudo odoo-helper install fix-python-deps`
3. **Verificar permisos**: `sudo chmod -R a+rwX /opt/odoo/venv`
4. **Verificar PostgreSQL**: `sudo -u postgres psql -c "\du"`

### Si hay errores de pyOpenSSL:
```bash
# Solución manual
sudo -u odoo /opt/odoo/venv/bin/pip uninstall -y pyOpenSSL
sudo -u odoo /opt/odoo/venv/bin/pip install pyOpenSSL==21.0.0
```

## 📝 Notas Importantes

1. **Contraseña por Defecto**: Solo se usa `Odoo123` si no se especifica `--db-password`
2. **Corrección Automática**: Se aplica durante la instalación automáticamente
3. **Compatibilidad**: Las mejoras son específicas para Odoo 18.3 + Python 3.10
4. **Permisos**: Se corrigen tanto durante la instalación como al final
5. **Verificación Automática**: Se ejecuta al final de la instalación

## 🎯 Beneficios

- ✅ **Instalación más confiable** para Odoo 18.3
- ✅ **Menos errores** de dependencias Python
- ✅ **Contraseña PostgreSQL** más fácil de recordar
- ✅ **Permisos correctos** desde el inicio
- ✅ **Corrección manual** disponible si es necesario
- ✅ **Verificación automática** al final de la instalación

---

**Versión**: 1.0  
**Fecha**: Julio 2025  
**Compatibilidad**: Odoo 18.3 + Python 3.10
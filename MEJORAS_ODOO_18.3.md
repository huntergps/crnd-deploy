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

## ✅ Verificación

### 1. **Verificar pyOpenSSL**
```bash
sudo -u odoo /opt/odoo/venv/bin/python3 -c "import OpenSSL; print('pyOpenSSL version:', OpenSSL.__version__)"
```

### 2. **Verificar Permisos**
```bash
ls -la /opt/odoo/venv/
ls -la /opt/odoo/logs/
ls -la /opt/odoo/data/
```

### 3. **Verificar Servicio**
```bash
sudo systemctl status odoo
sudo journalctl -u odoo --no-pager -n 20
```

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

## 🎯 Beneficios

- ✅ **Instalación más confiable** para Odoo 18.3
- ✅ **Menos errores** de dependencias Python
- ✅ **Contraseña PostgreSQL** más fácil de recordar
- ✅ **Permisos correctos** desde el inicio
- ✅ **Corrección manual** disponible si es necesario

---

**Versión**: 1.0  
**Fecha**: Julio 2025  
**Compatibilidad**: Odoo 18.3 + Python 3.10 
# CRND Deploy

Este es un script simple para instalar y configurar una instancia de [Odoo](https://www.odoo.com/) lista para producción.

Para desplegar [Odoo](https://www.odoo.com/) simplemente clona el repositorio en la máquina y ejecuta `sudo crnd-deploy.bash`.
Para obtener opciones de instalación, simplemente llama al comando `sudo crnd-deploy.bash --help`.

Además, este script soporta la instalación automática de
[PostgreSQL](https://www.postgresql.org/) y
[Nginx](https://nginx.org/en/) en la misma máquina.


## Requisitos de CRND-Deploy

Solo [Ubuntu](https://ubuntu.com/) 16.04, 18.04, 20.04 y 22.04 son soportados y probados.

Puede funcionar en otras distribuciones Linux basadas en Debian, pero sin ninguna garantía.

**Nota**: Odoo 18.3 requiere Ubuntu 22.04+ y Python 3.10+.

## Versiones de Odoo Soportadas

| Serie Odoo | Soporte            |
|------------|--------------------|
| 8.0        | ***no probado***   |
| 9.0        | ***no probado***   |
| 10.0       | ***no probado***   |
| 11.0       | :heavy_check_mark: |
| 12.0       | :heavy_check_mark: |
| 13.0       | :heavy_check_mark: |
| 14.0       | :heavy_check_mark: |
| 15.0       | :heavy_check_mark: |
| 16.0       | :heavy_check_mark: |
| 17.0       | :heavy_check_mark: |
| 18.0       | :heavy_check_mark: |
| 18.3       | :heavy_check_mark: |

## Opciones disponibles

Simplemente llama

```sh
sudo crnd-deploy.bash --help
```

Y ve el mensaje de ayuda con todos los comandos disponibles:

```
Uso:

    crnd-deploy.bash [opciones]    - instalar odoo

Opciones:

    --odoo-repo <repo>       - repositorio git para clonar odoo desde.
                               predeterminado: https://github.com/odoo/odoo
    --odoo-branch <branch>   - rama de odoo para clonar.
                               predeterminado: 18.3
    --odoo-version <version> - versión de odoo para clonar.
                               predeterminado: 18.3
    --odoo-user <user>       - nombre del usuario del sistema para ejecutar odoo con.
                               predeterminado: odoo
    --db-host <host>         - host de base de datos para ser usado por odoo.
                               predeterminado: localhost
    --db-user <user>         - usuario de base de datos para conectarse a la db con
                               predeterminado: odoo
    --db-password <password> - contraseña de base de datos para conectarse a la db con
                               predeterminado: odoo
    --install-dir <path>     - directorio para instalar odoo en
                               predeterminado: /opt/odoo
    --install-mode <mode>    - modo de instalación. puede ser: 'git', 'archive'
                               predeterminado: git
    --local-postgres         - instalar instancia local del servidor postgresql
    --proxy-mode             - Establece esta opción si planeas ejecutar odoo
                               detrás de un proxy (nginx, etc)
    --workers <workers>      - número de workers para ejecutar.
                               Predeterminado: 2
    --local-nginx            - instalar nginx local y configurarlo para esta
                               instancia de odoo
    --odoo-helper-dev        - Si se establece entonces usar versión dev de odoo-helper
    --install-ua-locales     - Si se establece entonces instalar también uk_UA y ru_RU
                               locales del sistema.
    -v|--version             - imprimir versión y salir
    -h|--help|help           - mostrar este mensaje de ayuda

Sugerencia:

    Echa un vistazo al proyecto [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit),
    y descubre la forma más fácil de gestionar tu instalación de Odoo.

    Solo notas breves sobre [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit):
        - iniciar nueva instancia de Odoo lista para producción en 1-2 minutos.
        - agregar complementos personalizados a tus instancias de Odoo en 5-10 minutos.
        - configuración de correo electrónico lista para usar: solo presiona un botón y
          agrega algunos registros a tu DNS, y obtén un correo electrónico funcional
        - hacer tu instancia de Odoo disponible para el mundo externo en 30 segundos:
          solo agrega un registro en tu DNS

    Si tienes alguna pregunta, contáctanos en
    [info@crnd.pro](mailto:info@crnd.pro),
    para que podamos programar una demostración en línea.
```

## Uso

Básicamente para instalar [Odoo](https://www.odoo.com/) en una nueva máquina tienes que hacer lo siguiente:

```sh
# Descargar script desde github
git clone https://github.com/crnd-inc/crnd-deploy

# Instalar odoo 18.3
sudo bash crnd-deploy/crnd-deploy.bash --odoo-version 18.3 --local-postgres --local-nginx
```

Este comando instalará y configurará automáticamente [Odoo](https://www.odoo.com/) 18.3,
[PostgreSQL](https://www.postgresql.org/), [Nginx](https://nginx.org/en/)
en la máquina, así obtienes una instalación completa de Odoo lista para producción.


## Mejora la calidad de tu servicio

Mejora tu servicio con nuestra solución [Helpdesk](https://crnd.pro/solutions/helpdesk) / [Service Desk](https://crnd.pro/solutions/service-desk) / [ITSM](https://crnd.pro/itsm).

Solo pruébalo en [yodoo.systems](https://yodoo.systems/saas/templates): elige la plantilla que te guste y comienza a trabajar.

Prueba todas las características disponibles de [Bureaucrat ITSM](https://crnd.pro/itsm) con [esta plantilla](https://yodoo.systems/saas/template/bureaucrat-itsm-demo-data-95).

## Seguimiento de errores

Los errores se rastrean en [https://crnd.pro/requests](https://crnd.pro/requests>).
En caso de problemas, por favor reporta allí.

## Mantenedor

![Center of Research & Development](https://crnd.pro/web/image/3699/300x140/crnd.png)

Nuestro sitio web es: [crnd.pro](https://crnd.pro/)

Este módulo es mantenido por la empresa [Center of Research & Development](https://crnd.pro).

Podemos proporcionarte más Soporte de Odoo, implementación de Odoo, personalización de Odoo, desarrollo de software de terceros de Odoo e integración, servicios de consultoría (más información disponible en [nuestro sitio](https://crnd.pro/our-services)).Nuestro objetivo principal es proporcionar el mejor producto de calidad para ti. 

Para cualquier pregunta [contáctanos](mailto:info@crnd.pro>).


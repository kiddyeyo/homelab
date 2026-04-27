# Infraestructura y Automatización del Homelab

Este repositorio contiene las configuraciones, despliegues y automatizaciones necesarias para la gestión del homelab. El proyecto se centra en el uso de herramientas de código abierto para el auto-alojamiento de servicios y la gestión centralizada de sistemas.

## Descripción del Homelab

La infraestructura está diseñada para ejecutar servicios persistentes utilizados en un entorno doméstico y de experimentación. El despliegue está automatizado para garantizar la consistencia entre los diferentes nodos y facilitar la recuperación ante fallos.

### Especificaciones de Hardware

El entorno se distribuye en los siguientes nodos físicos:

* **Nodo de Cómputo Principal (pve2):** Mini PC Beelink con procesador AMD Ryzen 7 6800U y 32 GB de RAM. Ejecuta Proxmox VE como hipervisor, alojando la mayoría de los servicios en contenedores Docker y máquinas virtuales.
* **Nodo de Almacenamiento (truenas):** Servidor dedicado con procesador Intel Core i3-8100 y 16 GB de RAM ejecutando TrueNAS SCALE. Provee almacenamiento persistente mediante protocolos NFS y SMB para el resto de los servicios.

---

## Catálogo de Servicios

A continuación se detallan los principales servicios desplegados y su función dentro del ecosistema:

| Servicio | Función | Propósito |
| :--- | :--- | :--- |
| **Immich** | Gestión Multimedia | Alternativa autogestionada para el respaldo y organización de fotografías con capacidades de reconocimiento mediante IA. |
| **Paperless-ngx** | Gestión Documental | Sistema de archivo digital con OCR para el procesamiento y búsqueda de documentos escaneados. |
| **Vaultwarden** | Seguridad | Implementación ligera de la API de Bitwarden para la gestión centralizada de credenciales. |
| **Traefik** | Proxy Inverso | Gestión de tráfico de red, terminación SSL mediante Let's Encrypt y enrutamiento dinámico de servicios. |
| **Pi-hole** | Filtrado DNS | Bloqueo de publicidad y rastreadores a nivel de red para todos los dispositivos conectados. |
| **Homepage** | Dashboard de Control | Panel de inicio que centraliza el acceso a los servicios y muestra estadísticas de estado en tiempo real. |
| **Monitoring Stack** | Observabilidad | Conjunto de herramientas (incluyendo Dozzle) para la supervisión de logs y consumo de recursos. |

---

## Metodología de Gestión

El homelab se gestiona mediante las siguientes herramientas y metodologías:

1. **Ansible:** Se utilizan playbooks y roles para la configuración base de los sistemas operativos, actualizaciones de seguridad y el despliegue inicial de Docker en los nodos.
2. **Docker Compose:** Cada aplicación se define de forma modular en su propio directorio mediante archivos de composición, permitiendo un aislamiento total y actualizaciones simplificadas.
3. **Gestión de Secretos (SOPS):** Los datos sensibles y credenciales están cifrados mediante SOPS, permitiendo el almacenamiento seguro de las configuraciones en sistemas de control de versiones.

### Estructura del Repositorio

* `ansible/`: Playbooks y archivos de inventario para la gestión de servidores.
* `[nombre-servicio]/`: Directorios individuales que contienen los archivos `docker-compose.yml` y configuraciones específicas de cada aplicación.
* `.ansible/`: Roles y módulos personalizados para tareas de administración.

---

*Nota: La documentación técnica detallada y los manuales de configuración paso a paso se encuentran en un repositorio de documentación privado.*

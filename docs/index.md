# Documentación de Infraestructura Homelab

## Sobre el Proyecto

Este sitio centraliza la documentación técnica del homelab, un ecosistema de servidores diseñado para el auto-alojamiento de servicios, la gestión de datos personales y la automatización de infraestructura. El objetivo es mantener un entorno controlado, seguro y documentado para la experimentación y el despliegue de aplicaciones productivas de uso personal.

## Arquitectura de Hardware

La infraestructura se apoya en dos nodos físicos principales, segmentando las tareas de computación y almacenamiento de datos:

* **Nodo de Cómputo (Proxmox):** Ejecutado en una unidad Mini PC Beelink con procesador AMD Ryzen 7 6800U y 32 GB de RAM. Este nodo actúa como el hipervisor principal, gestionando máquinas virtuales y contenedores para los servicios activos.
* **Nodo de Almacenamiento (TrueNAS):** Basado en hardware dedicado con procesador Intel Core i3-8100 y 16 GB de RAM, ejecutando TrueNAS SCALE. Este sistema garantiza la integridad de los datos mediante el sistema de archivos ZFS y provee almacenamiento persistente vía protocolos de red (NFS/SMB) al resto de la infraestructura.

## Pilares de la Infraestructura

El funcionamiento del laboratorio se basa en tres componentes fundamentales:

1. **Virtualización y Orquestación:** Uso de Proxmox VE para la gestión de recursos y Docker Compose para el despliegue modular de aplicaciones.
2. **Red y Seguridad:** Gestión de tráfico mediante OPNsense como firewall perimetral, Pi-hole para el filtrado de DNS y Traefik como proxy inverso modularizado para la gestión de certificados SSL y exposición segura de servicios.
3. **Observabilidad y Monitoreo:** Supervisión en tiempo real mediante Dozzle, organizado por grupos funcionales y con filtrado inteligente de logs para mantener la claridad operativa.
4. **Gestión de Datos:** Almacenamiento centralizado y políticas de respaldo para asegurar la disponibilidad de la información.

## Servicios Desplegados

El homelab integra diversas soluciones de software para cubrir necesidades específicas:

* **Gestión de Medios:** Immich para la organización y respaldo de fotografías.
* **Gestión Documental:** Paperless-ngx para el procesamiento y archivo digital de documentos mediante OCR.
* **Inteligencia Artificial:** LiteLLM para la gestión de modelos de lenguaje y Open WebUI como interfaz de interacción.
* **Seguridad:** Vaultwarden para la gestión centralizada de credenciales.
* **Monitoreo:** Dashboards de Homepage y herramientas de observabilidad para supervisar el estado de los contenedores y el rendimiento del hardware.

## Organización de la Documentación

El contenido de esta wiki está estructurado para facilitar la consulta técnica:
 **Infraestructura:** Detalles sobre la configuración de Proxmox, TrueNAS y el hardware base.
 **Red:** Configuración de reglas de firewall, VLANs y servicios de proxy.
 **Aplicaciones:** Guías específicas de instalación y mantenimiento para cada contenedor o servicio desplegado.

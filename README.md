# Powermeter

Aplicación nativa para macOS 13+, Intel y Apple Silicon. Muestra potencia estimada en la barra de menú, historial de 60 muestras, estado térmico y opción de inicio de sesión.

## Descargar

Descarga **Powermeter-universal.zip** desde [Releases](https://github.com/gvelasquez85/Powermeter/releases/latest), descomprime y copia Powermeter.app a Aplicaciones. El mismo paquete contiene **Intel (x86_64) y Apple Silicon (arm64)**. Requiere macOS 13 o posterior.

La aplicación tiene firma local ad hoc, sin notarización de Apple; macOS puede impedir su apertura hasta que autorices la aplicación desde Privacidad y seguridad. No es una distribución firmada con Developer ID.

## Compilar

Instala Xcode/Command Line Tools compatibles y ejecuta:

```sh
./scripts/test.sh
./scripts/build.sh
open dist/Powermeter.app
```

El script genera un binario universal y firma ad hoc para uso local. No está notarizado. Para distribuir fuera de uso local se necesita firma Developer ID y notarización.

## Medición y permisos

La medición comienza automáticamente al abrir la aplicación. Autoriza el diálogo de macOS para permitir la lectura. No hay que pulsar un botón para empezar ni para actualizar los vatios. Se ejecuta el `/usr/bin/powermetrics` de Apple con permisos administrativos mediante AppleScript. No se instala un daemon, no se modifica sudoers y no se ejecuta código de la aplicación como root. Las sesiones se renuevan automáticamente cada 12 horas; macOS puede volver a solicitar autorización. El intervalo se puede cambiar desde el panel; cambiarlo reconecta el recolector. Si se cancela el permiso o hay un error, **Reintentar conexión** permite recuperarse sin insistir con diálogos automáticos.

El recolector escribe datos en un archivo temporal impredecible creado por root, con lectura para el grupo del usuario. Un supervisor en primer plano mantiene viva la sesión autorizada, termina el recolector al cerrar la aplicación o al finalizar la sesión y elimina el archivo. Los errores se muestran en el panel. No hay telemetría ni conexión de red.

En Apple Silicon se muestra CPU; en Intel puede mostrarse **Package** (CPU más gráficos integrados y otros componentes). Son estimaciones y no representan el consumo total del equipo. El estado térmico es el de macOS, no una medida directa de temperatura ni una prueba definitiva de throttling. No se desactivan protecciones térmicas.

## Estado de validación

El script de pruebas verifica ocho casos de formatos Intel/Apple Silicon, datos inválidos y selección de última muestra. La medición privilegiada y el funcionamiento en Apple Silicon deben verificarse en hardware real. Esta primera versión usa sesiones de hasta 12 horas en lugar de un servicio persistente.

### Corrección local de herramientas

Los scripts detectan la definición duplicada de SwiftBridging y aplican un overlay al compilador Swift, sin modificar archivos del sistema. El ajuste se limita a `.build/toolchain`. Se necesita Python 3 únicamente para generar este ajuste cuando existe el conflicto.

## Indicador y panel

La barra muestra sólo `12.4W`, con actualización automática y dígitos de ancho fijo. `…W` indica conexión en curso y `!W` un problema que requiere atención. El panel presenta consumo, historial, estado térmico, intervalo y apertura al iniciar sesión. El archivo de potencia se lee incrementalmente.

Prueba del supervisor sin privilegios: `python3 Tests/Collector/test_supervisor.py`. Sustituye únicamente el ejecutable de medición por una fuente de datos de prueba y verifica inicio, datos, parada y limpieza; no acredita medición real.

## Icono

Icono propio minimalista: arco de medidor turquesa y rayo blanco sobre fondo oscuro. Fuentes reproducibles en `scripts/draw-icon.swift`; `./scripts/build-icon.sh` genera PNG e ICNS. El script de compilación incluye `Assets/AppIcon.icns` en el bundle.

## Licencia

MIT.

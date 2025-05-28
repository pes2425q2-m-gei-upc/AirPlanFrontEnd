# Render Build Instructions

## Configuración Automática
Este proyecto está configurado para desplegarse automáticamente en Render usando Docker.

## Variables de Entorno Necesarias (Opcional)
- `FLUTTER_VERSION`: 3.29.1 (o la versión que prefieras)
- `NODE_ENV`: production

## Configuración del Servicio en Render

### Método 1: Usando render.yaml (Recomendado)
El archivo `render.yaml` en la raíz del proyecto configurará automáticamente el servicio.

### Método 2: Configuración Manual
Si prefieres configurar manualmente:

1. **Tipo de Servicio**: Web Service
2. **Ambiente**: Docker
3. **Dockerfile Path**: `./Dockerfile`
4. **Build Command**: (dejar vacío)
5. **Start Command**: (dejar vacío)
6. **Puerto**: 80 (configurado automáticamente por Nginx)

## URLs de la Aplicación
- Producción: `https://[tu-app-name].onrender.com`
- El nombre se puede personalizar en la configuración de Render

## Características del Despliegue
- ✅ Imagen Docker multi-stage para optimización
- ✅ Nginx para servir archivos estáticos
- ✅ Manejo de rutas SPA
- ✅ Compresión GZIP
- ✅ Headers de seguridad
- ✅ Caché optimizado

## Tiempo de Construcción Estimado
- Primera construcción: ~5-10 minutos
- Construcciones subsecuentes: ~3-5 minutos (con caché Docker)

## Troubleshooting
- Si el build falla, verificar los logs en el dashboard de Render
- Asegurarse de que todas las dependencias estén en `pubspec.yaml`
- Verificar que no haya errores en `flutter analyze`

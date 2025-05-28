# AirPlan Frontend - Render Deployment

Este proyecto está configurado para desplegarse en Render como una aplicación web Flutter.

## Archivos de Configuración para Render

- `Dockerfile`: Contenedor Docker que construye la aplicación Flutter web
- `nginx.conf`: Configuración de Nginx para servir la aplicación
- `render.yaml`: Configuración de despliegue para Render
- `.dockerignore`: Archivos a excluir del contexto Docker

## Pasos para Desplegar en Render

### 1. Preparar el Repositorio
- Asegúrate de que todos los archivos de configuración estén en el repositorio
- Sube el código a GitHub

### 2. Configurar en Render
1. Ve a [render.com](https://render.com) y crea una cuenta
2. Haz clic en "New +" y selecciona "Web Service"
3. Conecta tu repositorio de GitHub
4. Render detectará automáticamente el `render.yaml` o puedes configurar manualmente:
   - **Environment**: Docker
   - **Dockerfile Path**: `./Dockerfile`
   - **Build Command**: (dejar vacío)
   - **Start Command**: (dejar vacío)

### 3. Variables de Entorno (Opcional)
Si necesitas configurar variables de entorno específicas:
- `FLUTTER_WEB=true`

### 4. Configuración de Dominio
- Render te proporcionará un dominio gratuito
- Opcionalmente puedes configurar un dominio personalizado

## Construcción Local

Para probar la construcción localmente:

### Windows:
```bash
build.bat
```

### Linux/macOS:
```bash
chmod +x build.sh
./build.sh
```

## Estructura del Despliegue

1. **Etapa de Construcción**: 
   - Usa imagen oficial de Dart
   - Instala Flutter
   - Construye la aplicación web

2. **Etapa de Runtime**:
   - Usa Nginx Alpine
   - Sirve los archivos estáticos
   - Maneja el enrutamiento de Flutter

## Características

- ✅ Optimizado para producción
- ✅ Configuración de Nginx para SPA
- ✅ Manejo de rutas de Flutter
- ✅ Headers de seguridad
- ✅ Caché optimizado para assets estáticos
- ✅ Imagen Docker multi-stage para menor tamaño

## Solución de Problemas

### Error de construcción
- Verifica que `pubspec.yaml` esté correctamente configurado
- Asegúrate de que todas las dependencias sean compatibles con web

### Error de rutas
- Verifica que `base href` esté configurado como `/`
- Asegúrate de que Nginx esté configurado para manejar rutas SPA

### Problemas de rendimiento
- Los assets estáticos tienen caché de 1 año
- La aplicación usa `--web-renderer html` para mejor compatibilidad

## Comandos Útiles

```bash
# Limpiar y reconstruir
flutter clean && flutter pub get

# Construir para web
flutter build web --release --web-renderer html

# Construir con base href específico
flutter build web --release --web-renderer html --base-href /

# Probar localmente
flutter run -d chrome
```

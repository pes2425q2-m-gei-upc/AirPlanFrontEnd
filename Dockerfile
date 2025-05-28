# Multi-stage Dockerfile para Flutter Web
# Etapa de build usando la imagen oficial de Flutter
FROM cirrusci/flutter:stable AS builder
WORKDIR /app

# Copiar dependencias y activar cache
COPY pubspec.* ./
RUN flutter pub get

# Copiar el resto del código y compilar para web
COPY . .
RUN flutter build web --release

# Etapa final: servir con NGINX
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html

# Exponer puerto
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]

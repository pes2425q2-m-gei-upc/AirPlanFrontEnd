# Multi-stage Dockerfile para Flutter Web
# Etapa de build usando Ubuntu 22.04 e Flutter 3.20.0
FROM ubuntu:22.04 AS builder
RUN apt-get update && apt-get install -y \
    curl \
    git \
    libglu1-mesa \
    unzip \
    xz-utils

# Clone Flutter SDK stable channel
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH"
WORKDIR /app

# Clonar el repositorio remoto para obtener el código fuente
RUN git clone https://github.com/pes2425q2-m-gei-upc/AirPlanFrontEnd.git . \
    && flutter pub get --verbose

# Compilar para web
RUN flutter build web --release

# Etapa final: servir con NGINX
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html

# Exponer puerto
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]

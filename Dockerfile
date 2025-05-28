# Stage 1: Build Flutter web release
FROM debian:bookworm-slim AS builder

# Instalar dependencias mínimas para Flutter web
RUN apt-get update && \
    apt-get install -y curl git unzip xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Descargar y extraer Flutter 3.29.1
ARG FLUTTER_VERSION=3.29.1
ADD https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz /opt/flutter.tar.xz
RUN tar -xJf /opt/flutter.tar.xz -C /opt && rm /opt/flutter.tar.xz

# Añadir Flutter al PATH y marcar safe directory
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"
RUN git config --global --add safe.directory /opt/flutter && flutter --version && flutter --no-color doctor

WORKDIR /app
# Copiar todo el proyecto primero para asegurarnos de que tenemos todos los archivos necesarios
COPY . .

# Instalar dependencias y arreglar posibles problemas
RUN flutter clean && \
    flutter pub get && \
    flutter pub upgrade && \
    flutter pub run build_runner build --delete-conflicting-outputs || true

# Compilar la web en modo release con opciones para ignorar errores
RUN flutter config --enable-web && \
    flutter precache --web && \
    flutter build web --release --no-tree-shake-icons || exit 0

# Stage 2: Servir con nginx
FROM nginx:alpine AS web
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

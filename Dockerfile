# Use the official Dart image as base
FROM dart:stable AS build

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run flutter doctor
RUN flutter doctor -v

# Enable flutter web
RUN flutter config --enable-web

# Copy the app files to the container
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the application files
COPY . .

# Build the Flutter web app
RUN flutter build web --release --base-href /

# Use nginx to serve the app
FROM nginx:alpine AS runtime

# Copy the built web app from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
RUN mkdir -p assets/fonts  # ← временная диагностика
RUN ls -la assets/          # ← покажет что скопировалось
RUN flutter build web --release

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

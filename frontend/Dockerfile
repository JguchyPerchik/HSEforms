# ── Stage 1: собрать Flutter Web ──────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# ── Stage 2: отдать через Caddy + HTTPS ───────────────────────────────────
FROM caddy:2-alpine
COPY --from=build /app/build/web /usr/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80 443

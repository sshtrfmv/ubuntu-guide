#!/usr/bin/env bash
# One-command installer for MTG v2 (FakeTLS Telegram MTProto proxy) on Ubuntu.
# https://github.com/9seconds/mtg
set -Eeuo pipefail
umask 077

PORT=3128
DOMAIN="www.cloudflare.com"
PUBLIC_IP=""
NAME="mtg-proxy"
INSTALL_DIR="/etc/mtg-proxy"
IMAGE="nineseconds/mtg:2"
OPEN_UFW=1

usage() {
  cat <<'USAGE'
Использование: sudo bash install-mtproto.sh [параметры]
  --port NUM       TCP-порт на VPS (по умолчанию 3128)
  --domain NAME    Имя TLS-маскировки (по умолчанию www.cloudflare.com)
  --ip IPV4        Публичный IPv4 сервера (если автоопределение не подходит)
  --no-ufw         Не добавлять правило UFW
  --help           Показать помощь

Пример:
  sudo bash install-mtproto.sh --port 8443 --domain www.cloudflare.com

Скрипт предназначен для НОВОЙ установки. При занятом порте или
существующем контейнере mtg-proxy он ничего не перезаписывает.
USAGE
}

log() { printf '\n[MTG] %s\n' "$*"; }
die() { printf '[ОШИБКА] %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --port|--domain|--ip)
      (($# >= 2)) || die "Не указано значение для $1"
      case "$1" in
        --port) PORT="$2" ;;
        --domain) DOMAIN="$2" ;;
        --ip) PUBLIC_IP="$2" ;;
      esac
      shift 2 ;;
    --no-ufw) OPEN_UFW=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Неизвестный аргумент: $1 (см. --help)" ;;
  esac
done

[[ "${EUID}" == "0" ]] || die "Запусти от root: sudo bash install-mtproto.sh"
[[ -r /etc/os-release ]] || die "Не найдена /etc/os-release"
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Скрипт рассчитан на Ubuntu (обнаружено: ${ID:-неизвестно})"
[[ "$PORT" =~ ^[0-9]{1,5}$ ]] || die "Неверный порт"
(( 10#$PORT >= 1024 && 10#$PORT <= 65535 )) || die "Выбери порт от 1024 до 65535"
[[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]{0,251}[a-zA-Z0-9])?$ ]] && [[ "$DOMAIN" == *.* ]] || die "Неверное доменное имя"
if [[ -n "$PUBLIC_IP" ]]; then
  [[ "$PUBLIC_IP" =~ ^[0-9.]+$ ]] || die "Для --ip нужен IPv4"
fi

log "Проверяю существующие сервисы"
if command -v docker >/dev/null 2>&1; then
  if ! docker info >/dev/null 2>&1; then
    die "Docker установлен, но недоступен. Проверь: systemctl status docker"
  fi
  if docker container inspect "$NAME" >/dev/null 2>&1; then
    die "Контейнер $NAME уже существует. Не меняю его и не раскрываю сохранённый секрет."
  fi
fi
if command -v ss >/dev/null 2>&1; then
  if ss -H -ltn "( sport = :$PORT )" | grep -q .; then
    die "TCP-порт $PORT уже занят. Используй --port НОВЫЙ_ПОРТ"
  fi
else
  die "Нет утилиты ss (пакет iproute2). Установи её перед продолжением."
fi

log "Устанавливаю необходимые пакеты (если отсутствуют)"
packages=()
command -v curl >/dev/null 2>&1 || packages+=(curl)
[[ -f /etc/ssl/certs/ca-certificates.crt ]] || packages+=(ca-certificates)
command -v docker >/dev/null 2>&1 || packages+=(docker.io)
if ((${#packages[@]})); then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends "${packages[@]}"
fi
systemctl enable --now docker >/dev/null

docker container inspect "$NAME" >/dev/null 2>&1 && die "Контейнер $NAME уже существует"
ss -H -ltn "( sport = :$PORT )" | grep -q . && die "Порт $PORT занят" || true

if [[ -z "$PUBLIC_IP" ]]; then
  log "Определяю публичный IPv4"
  PUBLIC_IP="$(curl -4fsS --connect-timeout 5 --max-time 12 https://api.ipify.org || true)"
fi
if [[ ! "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  die "Не получилось определить публичный IPv4. Повтори с --ip АДРЕС_СЕРВЕРА"
fi
IFS=. read -r a b c d <<< "$PUBLIC_IP"
for octet in "$a" "$b" "$c" "$d"; do
  ((10#$octet <= 255)) || die "Неверный публичный IP"
done

log "Загружаю образ MTG v2"
docker pull "$IMAGE" >/dev/null

log "Генерирую уникальный секрет FakeTLS"
SECRET="$(docker run --rm --entrypoint /mtg "$IMAGE" generate-secret --hex "$DOMAIN" | tr -d '\r\n')"
[[ "$SECRET" =~ ^ee[0-9a-fA-F]+$ ]] || die "Неожиданный формат секрета; установка остановлена"

# Fail closed: never overwrite a previous install directory.
[[ ! -e "$INSTALL_DIR" ]] || die "$INSTALL_DIR уже существует: не перезаписываю настройки"
install -d -m 700 "$INSTALL_DIR"
CONFIG="$INSTALL_DIR/config.toml"
printf 'secret = "%s"\nbind-to = "0.0.0.0:3128"\n' "$SECRET" > "$CONFIG"
chmod 600 "$CONFIG"

log "Запускаю контейнер с политикой автозапуска"
docker run -d \
  --name "$NAME" \
  --restart unless-stopped \
  --publish "${PORT}:3128/tcp" \
  --volume "$CONFIG:/config.toml:ro" \
  --log-opt max-size=5m --log-opt max-file=2 \
  "$IMAGE" >/dev/null

sleep 3
[[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" == true ]] || die "Контейнер не запустился: docker logs --tail 30 $NAME"

if ((OPEN_UFW)) && command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active'; then
  log "Добавляю правило UFW для TCP $PORT"
  ufw allow "${PORT}/tcp" comment "MTG proxy" >/dev/null
fi

log "Проверяю прослушивание TCP порта"
if ! ss -H -ltn "( sport = :$PORT )" | grep -q .; then
  die "Контейнер запущен, но публичный порт не слушается; проверь Docker"
fi

LINK="tg://proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
WEB_LINK="https://t.me/proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
printf '\n===============================================================\n'
printf ' MTProto (MTG FakeTLS) установлен и запущен\n'
printf ' Сервер:   %s\n' "$PUBLIC_IP"
printf ' Порт TCP: %s\n' "$PORT"
printf ' Контейнер: %s\n' "$NAME"
printf '\n Ссылка для Telegram:\n %s\n' "$LINK"
printf '\n Ссылка для открытия в браузере:\n %s\n' "$WEB_LINK"
printf '===============================================================\n'
printf '\nСохрани ссылку в менеджере паролей: она содержит секрет доступа.\n'
printf 'Если есть внешний firewall у провайдера, открой там TCP %s.\n' "$PORT"
printf 'Проверить: docker ps --filter name=%s\n' "$NAME"
printf 'Остановить: docker stop %s\n' "$NAME"

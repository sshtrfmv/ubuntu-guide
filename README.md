# Ubuntu VPS с нуля + Telegram MTProto Proxy

Пошаговая PDF-методичка на русском для новичков: первый запуск Ubuntu VPS, SSH-ключи и безопасность, UFW / Fail2ban, Docker, VPN, мониторинг, резервные копии на Google Drive и перенос на новый сервер.

Дополнительно — Bash-установщик [MTG v2](https://github.com/9seconds/mtg) (Telegram MTProto Proxy, FakeTLS), который запускает контейнер и выводит ссылку `tg://proxy` для подключения.

## Содержание

- **[PDF-методичка для новичков](docs/Ubuntu_VPS_guide_for_beginners_RU.pdf)** — 13 страниц с кликабельным оглавлением и закладками.
- **[Установщик MTProto](scripts/install-mtproto.sh)** — установка Docker (при необходимости), запуск MTG, генерация секретного ключа и ссылки.

## Быстрая установка MTProto

На чистом **Ubuntu VPS**, после клонирования репозитория:

```bash
sudo bash scripts/install-mtproto.sh
```

Свой порт и домен FakeTLS:

```bash
sudo bash scripts/install-mtproto.sh --port 8443 --domain example.org
```

Проверить параметры:

```bash
bash scripts/install-mtproto.sh --help
```

После установки скрипт выведет `tg://proxy?...` и `https://t.me/proxy?...`. **Не публикуйте эти ссылки**: они содержат секрет доступа к прокси.

> Скрипт предназначен для новой установки, а не обновления уже работающего прокси. Он не перезаписывает существующий контейнер `mtg-proxy` или занятый TCP-порт. Выберите порт, разрешённый в firewall хостинга. Проверьте также firewall Ubuntu: опубликованные Docker-порты могут обходить обычные правила UFW.

## Диагностика

```bash
sudo docker ps --filter name=mtg-proxy
sudo docker logs --tail 50 mtg-proxy
sudo ss -lnt '( sport = :3128 )'
```

Если использовали `--port`, замените `3128` на выбранный порт в последней команде.

Проверка доступности TCP снаружи: <https://check-host.net/check-tcp>.

## Безопасность

- Скрипт требует `sudo` и работает только на Ubuntu.
- Конфигурация хранится в `/etc/mtg-proxy/config.toml` с ограниченными правами.
- Не сохраняйте реальные токены, ключи, Docker env, `tg://proxy` и OAuth-файлы в Git.
- Для FakeTLS выберите домен осмысленно: это не делает соединение неотличимым от обычного HTTPS.
- **Создание резервной копии** не равно **проверке полного восстановления**: тестируйте сервисы на отдельном VPS.

## Ограничения

Установщик и PDF предназначены для самостоятельной установки. Bash-синтаксис проверен, но полноценный end-to-end запуск установщика на новом VPS пока не проводился. Конфигурации AWG, Xray и бота из другого проекта не включены в этот публичный шаблон.

## Источники

- [MTG v2](https://github.com/9seconds/mtg)
- [Docker Engine](https://docs.docker.com/engine/install/ubuntu/)
- [Restic](https://restic.readthedocs.io/)
- [Rclone](https://rclone.org/drive/)

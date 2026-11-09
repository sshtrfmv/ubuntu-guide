# Ubuntu VPS с нуля + Telegram MTProto Proxy

Пошаговая PDF-методичка на русском для новичков: первый запуск Ubuntu VPS, SSH-ключи и безопасность, UFW / Fail2ban, Docker, VPN, мониторинг, резервные копии на Google Drive и перенос на новый сервер.

Дополнительно — Bash-установщик [MTG v2](https://github.com/9seconds/mtg) (Telegram MTProto Proxy, FakeTLS), который запускает контейнер и выводит ссылку `tg://proxy` для подключения.

## Содержание

- **[PDF-методичка для новичков](docs/Ubuntu_VPS_guide_for_beginners_RU.pdf)** — 13 страниц с кликабельным оглавлением и закладками.
- **[Установщик MTProto](scripts/install-mtproto.sh)** — установка Docker (при необходимости), запуск MTG, генерация секретного ключа и ссылки.

## Быстрая установка MTProto

### На чистом Ubuntu VPS — одной командой

Команда загружает установщик из **этого репозитория** и запускает его от root. Перед запуском на сервере, которому доверяете, рекомендуем ознакомиться с [исходным кодом](scripts/install-mtproto.sh). Используйте её **только на новом VPS**, а не на сервере с уже настроенным MTG:

```bash
installer="$(mktemp)" && curl -fsSL https://raw.githubusercontent.com/sshtrfmv/ubuntu-guide/main/scripts/install-mtproto.sh -o "$installer" && sudo bash "$installer"; rm -f "${installer:-}"
```

Скрипт выведет две готовые ссылки — `tg://proxy` и `https://t.me/proxy`. Они содержат секрет, поэтому не отправляйте их в публичные чаты или issues.

Если хотите сначала проверить скачанный файл и задать параметры:

```bash
curl -fsSLo install-mtproto.sh https://raw.githubusercontent.com/sshtrfmv/ubuntu-guide/main/scripts/install-mtproto.sh
less install-mtproto.sh
sudo bash install-mtproto.sh --port 8443 --domain example.org
```

Проверки кода выполняет [GitHub Actions](.github/workflows/mtproto-check.yml): `bash -n`, ShellCheck и режим `--help`. Проверка **не** заменяет реальный запуск и тест подключения Telegram.

### Установка через клонирование репозитория (для новичков)

Откройте терминал **на Ubuntu VPS** (подключитесь к серверу по SSH). Затем выполняйте команды по порядку.

**Шаг 1. Установите Git**, чтобы скачать файлы проекта:

```bash
sudo apt update
sudo apt install -y git
```

**Шаг 2. Скачайте репозиторий с GitHub:**

```bash
git clone https://github.com/sshtrfmv/ubuntu-guide.git
```

**Шаг 3. Перейдите в скачанную папку:**

```bash
cd ubuntu-guide
```

**Шаг 4. Запустите установщик:**

```bash
sudo bash scripts/install-mtproto.sh
```

По окончании скрипт напечатает ссылку для подключения в Telegram. **Скопируйте и сохраните её в надёжном месте:** ссылка содержит секрет доступа к прокси.

> GitHub-аккаунт для клонирования этого публичного репозитория не нужен. Если папка `ubuntu-guide` уже существует, не запускайте `git clone` повторно — перейдите в неё командой `cd ubuntu-guide`.

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

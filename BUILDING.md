# Локальная сборка IPK KVAS

В репозитории есть upstream-`Makefile` OpenWrt/Entware и pipeline Jenkins, но
pipeline привязан к исходной установке Jenkins и содержит этапы копирования на
роутер и тестирования. Для локальной сборки, не зависящей от роутера, используйте
скрипты из `tools/`.

## Сборка

Из корня репозитория:

```sh
./tools/build-ipk.sh
./tools/verify-ipk.sh dist/kvas_1.1.9_beta-10-353_all.ipk
```

Версия и номер релиза по умолчанию берутся из `PKG_VERSION` и `PKG_RELEASE` в
`Makefile`. Их можно переопределить без изменения исходных файлов:

```sh
./tools/build-ipk.sh --release 353
```

Результатом является IPK в формате Entware, упакованный gzip и содержащий
`debian-binary`, `control.tar.gz` и `data.tar.gz`. Пакет имеет
`Architecture: all`; компилятор MIPS не требуется, поскольку KVAS состоит из
shell-скриптов и файлов данных.

Сборщик повторяет логику `Package/kvas/install` из `Makefile`. Он ничего не
копирует на роутер, не запускает `opkg`, не перезапускает службы и не выполняет
package hooks.

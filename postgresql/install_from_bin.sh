# Собираем PostgreSQL из бинарников

# 1. Установить зависимости и библиотеки
# 2. Скачать архив с исходным кодом
# 3. Распаковать архив
# 4.Перейти в папку с распакованным архивом и сделать make distclean, если нужно
# 5. Запустить ./configure с нужными ключами
# 6. Запустить make world или make
# 7. Запустить make install-world или make install
# 8. Создать пользователя postgres
# 9. Создать папку для данных (Data Directory) и выдать права на неё пользователю postgres
# 10. Инициализировать кластер (команда initdb)
# 11. Запустить сервер (команда pg_ctl)

# 1. Устанавливаем зависимости и билиотеки (здесь только самое необходимое)

sudo apt-get update
sudo apt-get install build-essential libreadline-dev zlib1g-dev
sudo apt-get install libssl-dev libicu-dev libsystemd-dev pkg-config
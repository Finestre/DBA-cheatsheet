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
# 10.  Настроить переменные окружения
# 11. Инициализировать кластер (команда initdb)
# 12. Запустить сервер (команда pg_ctl)
# 13. Подключиться к кластеру и проверить, что все работает
# 14. Настроить PostgreSQL как сервисную службу
# 15. Настроить запуск psql от обычного пользователя, которым входим в систему

# 1. Устанавливаем зависимости и билиотеки (здесь только самое необходимое, если нужно что-то еще, добавляем отдельно)

sudo apt-get update
sudo apt-get install build-essential libreadline-dev zlib1g-dev
sudo apt-get install libssl-dev libicu-dev libsystemd-dev pkg-config

# build-essential - "ящик с инструментами" - внутри него лежат компилятор gcc, утилита make
# libreadline-dev - файлы разработки для удобной командной строки (история команд, стрелочки).
# zlib1g-dev - файлы разработки для сжатия архивов (Postgres использует это для резервных копий и оптимизации)
# libssl-dev - файлы разработки для шифрования данных
# llibicu-dev  - файлы разработки для правильной работы с текстом.
# libsystemd-dev - файлы разработки для работы с главным менеджером процессов Linux — systemd.

# 2. Скачиваем архив, для примера версия 16.1

wget https://ftp.postgresql.org/pub/source/v16.1/postgresql-16.1.tar.gz


# 3.Распаковываем архив

tar -xvzf postgresql-16.1.tar.gz

# -x (extract) - извлечь
# -v (verbose) - подробно, распаковщик будет писать на экран название каждого файла, который она достает
# -z (gzip) — говорит, что архив сжат методом gzip (расширение .gz)
# -f (file) — файл, после ключей — это имя файла архива"


# 4. Идем в распакованную папку, проводим очистку

cd postgresql-16.1
make distclean

# После распаковки distclean запускать необязательно, но если уже пытались создать make, то очистка обязательна


# 5. Запускаем ./configure с нужными ключами или в версии по умолчанию

./configure
# или с ключами
./configure --prefix=/usr/local/pgsql/16 --with-openssl --with-icu --with-systemd --enable-debug

# Все ключи конфигурации можно найти здесь - https://postgrespro.ru/docs/postgresql/16/install-make#CONFIGURE-OPTIONS


# 6. Запускаем make world или make

make
# или если хотим с документацией и дополнительными расширениями, то 
make world
# или если хотим с документацией и дополнительными расширениями и ускорить процесс, то указываем флаг -j и указываем кол-во потоков
make -j4 world


# 7. Запускаем make install-world или make install

sudo make install
# или если запускали make world
sudo make install-world


# 8. Создаем пользователя postgres

sudo useradd -m -s /bin/bash postgres

# -m - создать домашнюю директорию (/home/postgres)
# -s /bin/bash — назначить командную оболочку Bash


# 9. Создаем папку для данных (Data Directory) и выдаем права на неё пользователю postgres

sudo mkdir -p /usr/local/pgsql/16/data
sudo chown postgres:postgres /usr/local/pgsql/16/data

# -p - создать и все родительские папки, если их нет


# 10.  Настраиваем переменные окружения

sudo su - postgres # переключаемся на пользователя postgres

# Редактируем файл .bashrc

cat >> ~/.bashrc <<EOF
export PATH=/usr/local/pgsql/16/bin:\$PATH
export PGDATA=/usr/local/pgsql/16/data
EOF

# Применяем настройки

source ~/.bashrc 

# Проверка

echo $PGDATA

# ответ должен быть таким /usr/local/pgsql/16/data 


# 11. Инициализируем кластер (команда initdb) только под пользователем postgres!!!!

/usr/local/pgsql/16/bin/initdb -D /usr/local/pgsql/16/data -k

# -k - включение контрольных сумм страниц данных


# 12. Запускаем сервер PostgreSQL (команда pg_ctl)

pg_ctl start -l /home/postgres/logfile 

# -l /home/postgres/logfile - сразу указываем куда пишем логи


# 13. Подключение к кластеру

psql

# проверим, что все работает

SELECT version();


# 14. Настраиваем PostgreSQL как сервисную службу

\q # выход из psql
pg_ctl stop # останавливаем сервер
exit # выходим из-под пользователя postgres
sudo nano /etc/systemd/system/postgresql-16.service # создаем файл sudo /etc/systemd/system/postgresql-16.service

# заполняем файл

[Unit]
Description=PostgreSQL 16 Database Server
Documentation=https://www.postgresql.org/docs/16/static/
After=network.target

[Service]
# Тип notify возможен, так как мы собирали с --with-systemd
Type=notify

# От кого запускать
User=postgres
Group=postgres

# Где лежат данные
Environment=PGDATA=/usr/local/pgsql/16/data

# Самая главная команда запуска. Обрати внимание: мы запускаем сам бинарник postgres, а не pg_ctl!
ExecStart=/usr/local/pgsql/16/bin/postgres -D ${PGDATA}

# Команда перезагрузки конфигов
ExecReload=/bin/kill -HUP $MAINPID

# Как правильно убивать процесс при остановке
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=0

[Install]
WantedBy=multi-user.target

# Обновляем список служб

sudo systemctl daemon-reload

# Включаем автозагрузку 

sudo systemctl enable postgresql-16

# Запускаем 

sudo systemctl start postgresql-16

# Проверяем

sudo systemctl status postgresql-16


# 15. Настраиваем запуск psql от обычного пользователя, которым входим в систему

# Выполнять от обычного пользователя

cat >> ~/.bashrc <<EOF
export PATH=/usr/local/pgsql/16/bin:\$PATH
EOF

source ~/.bashrc

# Финальная проверка подключения

psql -U postgres

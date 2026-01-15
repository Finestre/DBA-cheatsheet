-- Метрики для мониторинга Greenplum/Arenadata

/*
1. Block - Cluster Health
Тут собраны метрики, которые отвечают за общее состояние кластера
*/

-- 1.1 Database on/off
-- Одна большая лампочка, которая показывает, что кластер здоров, если загорелось красным, ищем проблему на других метриках
-- Эта метрика — "общая сирена", она не говорит что именно сломалось, она просто кричит "АВАРИЯ!"

select
	case
		when count(*) = 0 then 1
		else 0
	end as status_code
from pg_catalog.gp_segment_configuration
where status = 'd';

-- Если 1 - с кластером все отлично, если 0 - есть проблема, смотрим метрики ниже.


-- 1.2 Segment Status
-- Метрика показывает, есть ли упавшие сегменты

select
	sum(
		case
			when status ='u' then 1 else 0
		end) as segments_up,
	sum(
		case
			when status ='d' then 1 else 0
		end) as segments_down
from pg_catalog.gp_segment_configuration
where content != -1;

-- Если segments_down = 0, то все отлично, если segments_down > 0, то ищем упавшие сегменты:

select * from pg_catalog.gp_segment_configuration where status = 'd';

-- Более продвинутый запрос, сразу смотрим что за сегмент упал primary или mirror

select
    sum(
		case 
			when role = 'p' and status = 'd' then 1 
			else 0 
		end) as primary_down, -- подсчет упавших Primary сегментов (критично)
    sum(
		case 
			when role = 'm' and status = 'd' then 1 
			else 0 
		end) as mirror_down, -- подсчет упавших Mirror сегментов (потеря отказоустойчивости)
    sum(
		case 
			when status = 'd' then 1 
			else 0 
		end) as total_down -- общее количество упавших сегментов (опционально)
from pg_catalog.gp_segment_configuration
where content != -1;

/*
mirror_down > 0: WARNING 
cистема работает штатно, тормозов нет. Но если сейчас вылетит еще и primary на паре к этому зеркалу, то данные будут потеряны, база встанет.

primary_down > 0: CRITICAL 
обычно это означает, что Primary упал, и FTS (Fault Tolerance Service) переключил его роль на зеркало. Зеркало работает за главного. Старый Primary лежит (status 'd'). Кластер работает в "хромом" режиме. Нужно срочно чинить.
*/

-- Ищем проблемные сегменты

select * from pg_catalog.gp_segment_configuration where status = 'd';


-- 1.3 Replication Mode 
-- Самое главное что нужно от этой метрики - возможность мониторить процесс восстановления сегментов после падения

select
    sum(
		case 
			when mode = 's' then 1 
			else 0 
		end) as mode_synced, -- 's' = Synced (Синхронизировано), отлично.
    sum(
		case 
			when mode = 'c' then 1 
			else 0 
		end) as mode_change_tracking,  -- 'c' = Change Tracking. WARNING. Зеркало не получает данные.
    sum(
		case 
			when mode = 'r' then 1 
			else 0 
		end) as mode_resyncing  -- 'r' = Resyncing. Идет процесс восстановления.
from pg_catalog.gp_segment_configuration
where content != -1;

/*
1. mode_change_tracking > 0 
Какие-то сегменты потеряли связь со своими зеркалами. Primary сегменты работают в одиночку.
Любой сбой оборудования сейчас приведет к простою или потере данных.
Что делать:
Запустить восстановление: gprecoverseg

2. mode_resyncing > 0 
Прямо сейчас идет восстановление (recovery). Данные переливаются с Primary на Mirror.
Ничего не трогать. Ждать.
Можно следить за прогрессом с помощью утилиты gpstate -e в консоли сервера.
Во время ресинхронизации нагрузка на диски и сеть возрастает.
*/


-- 1.4 Segment Role
-- Метрика показывает mirror-сегменты, которые в данные момент работают как primary - это называется Unbalanced Cluster (разбалансированный кластер)

select
	sum(
		case
		when role ='p'  and preferred_role ='p' then 1 else 0
	end) as primaries_ok,
	sum(
		case
			when role ='p'  and preferred_role ='m' then 1 else 0
		end) as mirrors_as_primaries
from pg_catalog.gp_segment_configuration
where role = 'p' and content != -1;

/* Если mirrors_as_primaries > 0, нужно выполнить процедуру Rebalance командой gprecoverseg -r
Операция gprecoverseg -r вызывает кратковременный разрыв соединений к переключаемым сегментам.
Текущие запросы, которые затрагивают эти сегменты, могут упасть с ошибкой или зависнуть на пару секунд.
Лучше выполнять эту команду, когда нагрузка на базу минимальна (ночью или в технологическое окно).
*/
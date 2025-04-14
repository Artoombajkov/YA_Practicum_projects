/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT count (ID) AS sum_players,
		(SELECT COUNT(ID)
		FROM fantasy.users u 
		WHERE payer = 1) AS sum_pay_players,
		(SELECT COUNT(ID)
		FROM fantasy.users u 
		WHERE payer = 1) / count(ID)::NUMERIC AS dolya_payer
FROM fantasy.users u;		
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH race_sum_payer AS ( SELECT race_id,
							count(ID) AS race_sum_payer
						FROM fantasy.users u 
						WHERE payer =1
						GROUP BY race_id),
sum_players AS (SELECT race_id,
						count(id) AS sum_players
				FROM fantasy.users u
				GROUP BY race_id)
SELECT  race,
		race_sum_payer,
		sum_players,
		race_sum_payer/sum_players::NUMERIC AS dolya_payer_race
FROM sum_players sp 
JOIN race_sum_payer rsp ON sp.race_id = rsp.race_id
JOIN fantasy.race r ON sp.race_id = r.race_id 

		
 
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT count(amount),
		sum(amount),
		min(amount),
		max(amount),
		avg(amount),
		percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS mediana,
		stddev(amount) AS stand_otclonenie
FROM fantasy.events e;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT (SELECT COUNT(amount)
		FROM fantasy.events 
		WHERE amount = 0) AS sum_0_amount,
		(SELECT COUNT(amount)
		FROM fantasy.events  
		WHERE amount = 0)/ count(amount)::REAL  AS dolya_sum_0
FROM fantasy.events e;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
WITH user_events AS (
 SELECT
  		u.id,
  		payer,
  		COUNT(e.transaction_id) AS total_transactions,
  		SUM(e.amount)  AS total_amount
 FROM  fantasy.users u
 RIGHT JOIN fantasy.events e ON u.id = e.id
 WHERE e.amount <> 0 -- обавил общую фильрацию
 GROUP BY u.id,
  		payer
)
SELECT
 		CASE WHEN payer = 1 THEN 'payer' ELSE 'not_payer' END AS payer_type,
 		COUNT(DISTINCT id) AS total_users,
 		AVG(total_transactions) AS sr_pokupok,
 		AVG(total_amount) AS sr_sum_pokupok
FROM
 user_events
GROUP BY
 payer_type;


-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH item_sales AS (
 SELECT
  item_code,
  COUNT(*) FILTER (WHERE amount <> 0) AS total_sales
 FROM fantasy.events e 
 GROUP BY item_code
), 
item_popularity AS (
 SELECT it.item_code,
  		total_sales,
 		 total_sales::NUMERIC / (SELECT SUM(total_sales) FROM item_sales) AS relative_sales,
  		COUNT(DISTINCT id) AS buyers_count,
  		COUNT(DISTINCT id)::numeric / (SELECT COUNT(DISTINCT id) FROM fantasy.users) AS buyers_share
 FROM  item_sales AS it
 JOIN fantasy.events is2 ON it.item_code = is2.item_code
 GROUP BY
  it.item_code,
  total_sales
)
SELECT
 game_items 
 total_sales,
 relative_sales,
 buyers_count,
 buyers_share
FROM
 item_popularity ip 
JOIN fantasy.items i ON ip.item_code = i.item_code 
ORDER BY
 buyers_share DESC;
		

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH sum_players AS (
  SELECT   race_id,
      count(id) AS sum_players
  FROM fantasy.users u
  GROUP BY race_id
),
trans_users AS (
  SELECT  race_id,
      	  COUNT (id) AS sum_u_payers
  FROM fantasy.users u
  WHERE id IN (SELECT id FROM fantasy.events WHERE amount > 0)
  GROUP BY race_id
),
pokupki AS (
  SELECT u.race_id,
		count(id)/sum_u_payers::NUMERIC AS kolich_pocupok 
  FROM fantasy.users u
  JOIN trans_users tp ON u.race_id= tp.race_id
  WHERE payer = 1 AND id IN (SELECT id FROM fantasy.events WHERE amount > 0) -- провел фильтрацию игроков
  GROUP BY u.race_id,
  			sum_u_payers
),
all_data_users AS (
SELECT DISTINCT u.id,
		r.race_id,
		count(transaction_id) OVER (PARTITION BY e.id, r.race_id) AS SUM_TRANS,
		avg (amount) OVER (PARTITION BY e.id, r.race_id) AS avg_amount,
		sum (amount) OVER (PARTITION BY e.id, r.race_id) AS SUM_amount
FROM fantasy.events e 
JOIN fantasy.users u ON e.id = u.id
  JOIN fantasy.race r ON u.race_id = r.race_id
)
SELECT race AS Расса,
    sum_players AS Общее_колво_игроков,
    sum_u_payers AS Сколько_игроков_покупают,
    sum_u_payers/sum_players::NUMERIC AS Доля_покупающих_от_общего_числа_игроков, 
    kolich_pocupok AS Доля_платящих_игроков_от_количества_игроков_которые_совершили_покупки,
    avg(SUM_TRANS) AS среднее_количество_покупок_на_одного_игрока,
	avg(SUM_amount) / avg(SUM_TRANS) AS средняя_стоимость_одной_покупки_на_одного_игрока,
	avg(SUM_amount) AS средняя_суммарная_стоимость_всех_покупок_на_одного_игрока
FROM sum_players sp 
JOIN trans_users tu ON sp.race_id = tu.race_id
JOIN pokupki p ON sp.race_id = p.race_id
JOIN all_data_users adu ON tu.race_id = adu.race_id
JOIN fantasy.race r ON sp.race_id = r.race_id 
GROUP BY race,
		sum_players,
		sum_u_payers,
		kolich_pocupok
ORDER BY Общее_колво_игроков DESC
-- Задача 2: Частота покупок

WITH count_trans AS (
SELECT DISTINCT ID,
		date,
		transaction_id,
		count(transaction_id) OVER (PARTITION BY ID) AS count_tran
FROM fantasy.events e 
WHERE amount IS NOT NULL 
	AND amount > 0
),
date_tran AS (SELECT DISTINCT id,
		count_tran,
		date::DATE,
		LAG (date::date) over(PARTITION BY id ORDER BY date), -- сделал подсчет по дате, в твоем комменте в интогов запросе так же стоит по транзакции
		date::date - LAG (date::date) over(PARTITION BY id ORDER BY date) AS date_tran -- и тут тоже
FROM count_trans
WHERE count_tran >= 25
ORDER BY date
),
mean_values_per_id AS (
SELECT id,
        avg(count_tran) AS count_tran,
        avg(date_tran) AS date_tran -- добавил расчет средней даты между покупками
FROM date_tran
GROUP BY id
),
group_u AS (
	SELECT *,
			NTILE(3) OVER (ORDER by date_tran) AS group_u
	FROM mean_values_per_id
),
count_group AS (
	SELECT group_u,
			count(ID) AS count_group
	FROM group_u
	GROUP BY group_u
)
SELECT CASE 
		WHEN group_u = 1 THEN 'низкая частота'
		WHEN group_u = 2 THEN 'умеренная частота'
		WHEN group_u = 3 THEN 'высокая частота'
		END,
		COUNT(DISTINCT gu.id) AS total_buyers,
 		COUNT(DISTINCT CASE WHEN payer = 1 THEN u.id END) AS payers_count,
 		COUNT(DISTINCT CASE WHEN payer = 1 THEN gu.id END)/ COUNT(DISTINCT u.id)::NUMERIC AS payers_share,
		AVG(count_tran), 
		round( avg(date_tran)) AS ср_дней_между_покупками
FROM group_u gu 
JOIN fantasy.users u ON gu.id = u.id
GROUP BY group_u
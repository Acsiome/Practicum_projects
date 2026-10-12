/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Арина Неб
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
WITH 
common_users AS 
(SELECT COUNT(id) AS total_users, -- общее количество игроков, зарегистрированных в игре;
	   SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users --количество платящих игроков
FROM fantasy.users)
SELECT *,
		ROUND(paying_users::NUMERIC/total_users, 3) AS paying_percentage --доля платящих игроков от общего количества пользователей
FROM common_users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH 
common_users AS 
(SELECT r.race, --раса персонажа
	   SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users, --количество платящих игроков по расам
	   COUNT(u.id) AS total_users -- общее количество игроков, зарегистрированных в игре по расам;
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id 
GROUP BY r.race)
----
SELECT  *,
		ROUND(paying_users::NUMERIC/total_users, 3) AS paying_percentage --доля платящих игроков от общего количества пользователей по расам
FROM common_users;


-- Задача 2. Исследование внутриигровых покупок 
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS total_purchases_count, --	общее количество покупок		
		SUM(amount) AS total_price, --суммарная стоимость всех покупок;
		MIN(amount) AS lowest_price, --минимальное значение суммы покупки
		MAX(amount) AS highest_price, --максимальное значение суммы покупки
		ROUND(AVG(amount::NUMERIC),2) AS average_price, --среднее значение суммы покупки	
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median, --медиана
		ROUND(STDDEV(amount::NUMERIC), 2) AS stand_dev --стандартное отклонение
FROM fantasy.events
WHERE amount<>0 

-- 2.2. Аномальные нулевые покупки:
SELECT  COUNT(transaction_id) FILTER (WHERE amount = 0)  AS null_price_purchases, -- абсолютное количество покупок с нулевой стоимостью
		COUNT(transaction_id) AS total_purchases, --общее количество покупок
		COUNT(transaction_id) FILTER (WHERE amount = 0) / COUNT(*)::FLOAT AS null_price_percentage --	процент покупок со стоимостью 0 от общего количества
FROM fantasy.events


-- 2.3. Сравнительный анализ активности платящих и неплатящих игроков:
WITH 
user_counts AS
	(SELECT SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users, --количество платящих игроков
	   		SUM(CASE WHEN payer = 0 THEN 1 ELSE 0 END) AS non_paying_players --количество неплатящих игроков
	 FROM (SELECT u.id, u.payer
		  FROM fantasy.users u
		  JOIN fantasy.events e ON u.id = e.id
		  WHERE e.transaction_id IS NOT NULL AND amount<>0
		  GROUP BY u.id, u.payer) AS unique_users_with_purchases),	
----
purchase_counts_paying_players AS 
	(SELECT COUNT(transaction_id ) AS purchases_of_paying_players --количество покупок у платящих игроков    	
	 FROM fantasy.users u
	 JOIN fantasy.events AS e ON u.id=e.id
	 WHERE u.payer = 1  AND amount<>0),
 ----
 purchase_counts_nonpaying_players AS 
	(SELECT COUNT(transaction_id ) AS purchases_of_non_paying_players --количество покупок у неплатящих игроков    	
	 FROM fantasy.users AS u
	 JOIN fantasy.events AS e ON u.id=e.id
	 WHERE u.payer = 0  AND amount<>0),
 ----
total_sum_paying_users AS
	(SELECT SUM(amount) AS total_amount_paying_users --сумма потраченная платящими игроками
	 FROM fantasy.events AS e
	 JOIN fantasy.users AS u ON u.id=e.id
	 WHERE u.payer =1 AND e.amount<>0),
----
total_sum_non_paying_users AS
	(SELECT SUM(amount) AS total_amount_non_paying_users --сумма потраченная неплатящими игроками
	 FROM fantasy.events AS e
	 JOIN fantasy.users AS u ON u.id=e.id
	 WHERE u.payer =0 AND e.amount<>0)
----	 
SELECT  paying_users,
		non_paying_players,
		ROUND(purchases_of_paying_players::NUMERIC/paying_users, 2) AS avg_count_paying_players, --среднее количество покупок у платящих игроков 
		ROUND(purchases_of_non_paying_players::NUMERIC/non_paying_players,2) AS avg_count_non_paying_players,  --среднее количество покупок у неплатящих игроков 
		ROUND(total_amount_paying_users::NUMERIC/paying_users, 2) AS avg_sum_paying_players, --средняя суммарная стоимость покупок на одного платящего игрока
		ROUND(total_amount_non_paying_users::NUMERIC/non_paying_players, 2) AS avg_sum_non_paying_players --средняя суммарная стоимость покупок на одного неплатящего игрока
FROM user_counts uc
JOIN purchase_counts_paying_players AS pcpp ON TRUE
JOIN purchase_counts_nonpaying_players AS pcnp ON TRUE
JOIN total_sum_paying_users AS tspu ON TRUE
JOIN total_sum_non_paying_users AS tsnpu ON TRUE;

-- 2.4. Популярные эпические предметы:
WITH number_of_products_sold AS
(SELECT i.item_code,
		game_items,
		COUNT(transaction_id) AS sold_count, --абсолютное количество продаж
		COUNT(DISTINCT e.id) AS unique_buyers --пользователи, купившие предметы
FROM fantasy.events AS e
RIGHT JOIN fantasy.items AS i ON e.item_code=i.item_code
WHERE amount<>0
GROUP BY i.item_code),
----
total_players AS 
  (SELECT COUNT(DISTINCT id) AS all_users --общее количество пользователей, совершивших покупки
   FROM fantasy.events
   WHERE transaction_id IS NOT NULL AND amount <> 0),
 ----
  total_purchases AS 
  (SELECT COUNT(*) AS all_purchases --общее количество покупок
   FROM fantasy.events
   WHERE amount<>0)
----
SELECT nops.game_items,
		sold_count, --абсолютное количество продаж
		ROUND(sold_count::NUMERIC/all_purchases, 4) AS relative_items_count, --относительное количество продаж
		ROUND(unique_buyers::NUMERIC/all_users,4) AS relative_users_count --доля игроков, которые хотя бы раз покупали этот предмет
FROM number_of_products_sold AS nops
CROSS JOIN total_purchases
CROSS JOIN total_players
ORDER BY relative_users_count DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH total_users_per_race AS
(SELECT r.race,
		COUNT(*) AS all_users-- общее количество зарегистрированных игроков
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race),
----
unique_users_per_race AS
(SELECT r.race,
		COUNT(DISTINCT e.id) AS unique_buyers --количество игроков, которые совершают внутриигровые покупки		
 FROM fantasy.events AS e
 JOIN fantasy.users AS u ON e.id=u.id 
 LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
 WHERE amount<>0
 GROUP BY r.race
),
----
paying_unique_users_per_race AS
(SELECT r.race,
		COUNT(DISTINCT e.id) AS paying_unique_buyers --количество платящих игроков, которые совершают внутриигровые покупки	
 FROM fantasy.events AS e
 JOIN fantasy.users AS u ON e.id=u.id
 LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
 WHERE u.payer=1 AND amount<>0
 GROUP BY r.race),
 ----
 purchase_data AS (
  SELECT r.race,
    	 COUNT(*) AS total_purchases, -- всего покупок
    	 SUM(e.amount) AS total_amount -- сумма всех покупок
  FROM fantasy.events AS e
  JOIN fantasy.users AS u ON e.id=u.id 
  LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
  WHERE amount<>0
  GROUP BY r.race),
----
avg_data AS (
  SELECT pd.race,
    pd.total_purchases, --общее количество покупок
    pd.total_amount, --общая сумма
    uupr.unique_buyers, --количество игроков, которые совершают внутриигровые покупки	
    ROUND(pd.total_purchases::NUMERIC / NULLIF(unique_buyers, 0), 2) AS avg_purchases_per_user, --среднее количество покупок на одного игрока
    ROUND(pd.total_amount::NUMERIC / NULLIF(pd.total_purchases, 0), 2) AS avg_amount_per_purchase, --средняя стоимость одной покупки на одного игрока
    ROUND(pd.total_amount::NUMERIC / NULLIF(unique_buyers, 0), 2) AS avg_total_spent_per_user --средняя суммарная стоимость всех покупок на одного игрока.
  FROM purchase_data AS pd
  JOIN unique_users_per_race AS uupr ON pd.race = uupr.race)
 ----
SELECT  tupr.race,
		tupr.all_users,
		uupr.unique_buyers,
		ROUND(COALESCE(uupr.unique_buyers, 0)::NUMERIC / tupr.all_users, 4) AS relative_unique_buyers, --доля игроков, совершавщих покупки,от общего количества
		paying_unique_buyers,
		ROUND(COALESCE(puupr.paying_unique_buyers, 0)::NUMERIC / uupr.unique_buyers, 4) AS relative_paying_unique_buyers,
		avg_purchases_per_user, 
		avg_amount_per_purchase,
		avg_total_spent_per_user
FROM total_users_per_race AS tupr
LEFT JOIN unique_users_per_race AS uupr ON tupr.race = uupr.race
LEFT JOIN paying_unique_users_per_race AS puupr ON uupr.race=puupr.race
LEFT JOIN avg_data ad ON tupr.race = ad.race;

-- Задача 2: Частота покупок
WITH 
purchases_with_lags AS (
  SELECT 
    e.id,
    u.payer,
    e.date,
    LAG(e.date) OVER (PARTITION BY e.id ORDER BY e.date) AS prev_date
  FROM fantasy.events e
  JOIN fantasy.users u ON e.id = u.id
  WHERE e.amount<>0
),
----Считаем дни между покупками
days_between_purchases AS (
  SELECT 
    id,
    payer,
    date,
    prev_date,
    CASE 
      WHEN prev_date IS NOT NULL THEN DATE_PART('day', date::timestamp  - prev_date::timestamp)
      ELSE NULL
    END AS days_between --количество дней между покупками
  FROM purchases_with_lags
),
----
user_purchase_stats AS 
(SELECT id,
   		payer,
    COUNT(*) AS total_purchases,
    ROUND(AVG(days_between)::NUMERIC, 2) AS avg_days_between
  FROM days_between_purchases
  GROUP BY id, payer),
---Выполняем деление на 3 группы по показателю среднего интервала в днях между покупками
  ranked_users AS 
  (SELECT *,
    NTILE(3) OVER (ORDER BY avg_days_between) AS freq_group_rank
  FROM user_purchase_stats
  WHERE total_purchases >= 25
),
---Присваиваем названия группам
labeled_users AS (
  SELECT *,
    CASE freq_group_rank
      WHEN 1 THEN 'высокая частота'
      WHEN 2 THEN 'умеренная частота'
      WHEN 3 THEN 'низкая частота'
    END AS frequency_group
  FROM ranked_users
)
----
SELECT frequency_group,
		 COUNT(*) AS unique_buyers , --количество игроков, которые совершили покупки
		 COUNT(*) FILTER (WHERE payer = 1) AS paying_users, --количество платящих игроков, совершивших покупки
		 ROUND(COUNT(*) FILTER (WHERE payer = 1)::NUMERIC / COUNT(*), 4) AS relative_paying_unique_buyers, --доля платящих игроков от общего количества игроков, совершивших покупку
  		ROUND(AVG(total_purchases), 2) AS avg_purchases_per_user, --среднее количество покупок на одного игрока
  		ROUND(AVG(avg_days_between), 2) AS avg_days_between_purchases --среднее количество дней между покупками на одного игрока
FROM labeled_users
GROUP BY frequency_group
ORDER BY frequency_group;

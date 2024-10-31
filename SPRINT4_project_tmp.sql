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
SELECT COUNT(id), SUM(payer), sum(payer)*1.0/count(id)
FROM fantasy.users u 
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT race_id ,
SUM(payer),
COUNT(id),
SUM(payer)::numeric/COUNT(id)
FROM fantasy.users u 
GROUP BY race_id 
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(amount),
SUM(amount),
MIN(amount)::numeric,
MAX(amount),
AVG(amount),
stddev(amount),
percentile_cont(0.50) WITHIN GROUP(ORDER BY amount)
FROM fantasy.events e 
-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(transaction_id)::numeric /(SELECT COUNT(amount)
										FROM fantasy.events e),
		COUNT(amount) AS total_zero
FROM fantasy.events e 
WHERE amount = 0
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
(WITH ert AS 
(SELECT 
    u.id AS total_players,
    COUNT(e.transaction_id) AS many_count,
    SUM(e.amount) AS many_sum
FROM fantasy.users u 
JOIN fantasy.events e USING(id)
WHERE u.payer =1 AND amount>0
GROUP BY id)
SELECT 'payer' as payer_type, 
COUNT(total_players),
AVG(many_count),
AVG(many_sum)
FROM ert)
UNION
(WITH tre AS 
(SELECT  
    u.id AS total_players, 
    COUNT(e.transaction_id) AS non_count,
    SUM(e.amount) AS non_sum
FROM fantasy.users u 
JOIN fantasy.events e USING(id)
WHERE u.payer =0 AND amount>0
GROUP BY id)
SELECT 'non-payer' as payer_type,
COUNT(total_players),
AVG(non_count),
AVG(non_sum)
FROM tre)
-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH total_one AS 
(SELECT DISTINCT i.item_code AS code,
i.game_items AS names ,
COUNT(e.transaction_id)OVER(PARTITION BY i.item_code) AS kol_buy,  --кол-вопродаж каждого предмета
COUNT(e.amount)OVER() AS total,
COUNT(e.transaction_id)OVER(PARTITION BY i.item_code)::numeric/COUNT(e.amount)OVER() AS dolyaprodash
FROM fantasy.items i 
JOIN fantasy.events e USING(item_code)
ORDER BY kol_buy DESC),
tre AS (SELECT DISTINCT i.item_code AS code,
		COUNT(DISTINCT e.id) AS players_buy_skin,
		COUNT(DISTINCT e.id)::numeric/(SELECT COUNT(DISTINCT id)FROM fantasy.events e WHERE amount>0) AS dolya_players
		FROM fantasy.items i 
		JOIN fantasy.events e USING(item_code)
		JOIN fantasy.users u  USING(id)
		WHERE amount > 0
		GROUP BY i.item_code
		ORDER BY players_buy_skin DESC)
				SELECT code,
				kol_buy,
				total,
				dolyaprodash,
				players_buy_skin,
				dolya_players
				FROM total_one
				JOIN tre USING(code)
				ORDER BY kol_buy DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH cte1 AS(
    SELECT 
        race, 
        COUNT(id) AS total_users --общее кол-во зарегестрированных игрок
    FROM fantasy.users u 
    JOIN fantasy.race r USING(race_id)
    GROUP BY race
), 
cte2 AS (
    SELECT 
        race, 
        COUNT(DISTINCT e.id) AS buying_players, -- игроки совершившие покупку
        COUNT(amount) AS transaction_count --кол-во транзакций
    FROM fantasy.users u 
    JOIN fantasy.race r USING(race_id)
    JOIN fantasy.events e USING(id)
    WHERE amount > 0
    GROUP BY race
),  
cte3 AS (
    SELECT 
        race, 
        COUNT(DISTINCT id) AS players_buying, --игроки, кот купили
        COUNT(amount) AS count_amount ,  --общее кощ-во покупок,
        SUM(amount) AS sum_amount--сумма покупок
    FROM fantasy.users u
    JOIN fantasy.race r USING(race_id)
    JOIN fantasy.events e USING(id)
    GROUP BY race
),
cte4 AS (
    SELECT 
        race,
        COUNT(DISTINCT id) AS payer_count
    FROM fantasy.users u
    JOIN fantasy.race r USING(race_id)
    JOIN fantasy.events e USING(id)
    WHERE payer = 1 AND amount > 0
    GROUP BY race
)
SELECT 
    race, 
    total_users,
    buying_players,
    buying_players::NUMERIC / total_users AS buying_share,
    payer_count::NUMERIC /players_buying AS paying_share, --доля платящих, которые совершили покупку
    transaction_count::NUMERIC/players_buying AS average_purchases,
    sum_amount::NUMERIC/players_buying AS total_purchases,
    sum_amount::NUMERIC/transaction_count AS average_count
FROM cte1
JOIN cte2 USING(race)
JOIN cte3 USING(race)
JOIN cte4 USING(race)
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
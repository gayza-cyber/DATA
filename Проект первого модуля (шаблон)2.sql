/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Алмуратов Олжас
 * Дата: 22.10.2024
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT case 
	when a.days_exposition <= 30 then 'менее месяца'
	when a.days_exposition <= 90 and a.days_exposition >= 31 then 'более месяца'
	when a.days_exposition <= 180 and a.days_exposition >= 91 then 'до полугода'
	when a.days_exposition >= 181 then  'более полугода'
end as rangs,
case when c.city = 'Санкт-Петербург' then 'Санкт-Петербург'
else 'ЛенОбл'
end as category,
ROUND(AVG(a.last_price::numeric / f.total_area::numeric),2) as avg_price_one_meters, ROUND(AVG(f.total_area::numeric),2) as P,
percentile_cont(0.50) within group(order by f.rooms) as avg_rooms,
percentile_cont(0.50) within group(order by f.balcony) as avg_balcony,
percentile_cont(0.50) within group(order by f.floors_total) as floors_total_avg, 
ROUND(AVG(a.days_exposition::numeric) ,2) as avg_days_exposition, 
COUNT(id) as count_desk
from real_estate.flats f 
join real_estate.advertisement a USING(id)
join real_estate.city c USING(city_id)
join real_estate.type t USING(type_id)
WHERE id IN (SELECT * FROM filtered_id) and a.days_exposition  is not null and type_id = 'F8EM'
group by category,rangs
order by category DESC


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT *
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
total_result as (
select id, 
days_exposition,
to_char(first_day_exposition,'Mon') as month_exposition, --дата (месяц) выставки
to_char(first_day_exposition + days_exposition * interval '1 day','Mon') as month_exposition_end, --дата продажи(месяц)
total_area,
last_price,
rooms,
balcony,
city,
floor
from filtered_id
join real_estate.advertisement a USING(id)
join real_estate.city c USING(city_id)
where (EXTRACT(year from first_day_exposition) between 2015 and 2018) and 
(EXTRACT(year from first_day_exposition + days_exposition * interval '1 day') between 2015 and 2018) 
),
ert as(
select month_exposition as Month, --выводим месяц
COUNT(id) as total_desk_start,
ROUND(AVG(last_price::numeric / total_area::numeric),2) as one_meters_start,
ROUND(AVG(total_area::numeric),2) as avg_p_start,
RANK()over(order by count(id)DESC) as rank_created_desk
from total_result
where days_exposition is not null
group by Month
order by Month  
),-- дата выставления публикации
tre as (
select month_exposition_end as Month,
COUNT(id) as total_desk_buy,
ROUND(AVG(last_price::numeric / total_area::numeric),2) as one_meters_buy,
ROUND(AVG( total_area::numeric),2) as avg_p_buy,
RANK()over(order by count(days_exposition) DESC) as rank_finished_desk
from total_result
where days_exposition is not null
group by Month
order by Month
) --дата окончания публикации
select Month,total_desk_start,
rank_created_desk,
total_desk_buy,
rank_finished_desk,
one_meters_start,
one_meters_buy,
avg_p_start,
avg_p_buy
from ert 
join tre USING(Month)



-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
select c.city , NTILE(4)over (order by AVG(days_exposition)) as sorting_groups,
RANK()OVER(order by count(id)DESC) as rank_count,-- ранк по кол-ву объявлений
COUNT(a.id) as total_desk,
COUNT(a.days_exposition) as finish_desk ,
ROUND(COUNT(a.days_exposition)::numeric /  COUNT(a.id), 2) as share_finish_desk,
ROUND(AVG(a.last_price::numeric / f.total_area::numeric),2) as meter_cost,
ROUND(AVG( f.total_area::numeric),2) as average_area,
ROUND(AVG(a.days_exposition::numeric),2) as duration_desk,
ROUND(MIN(a.last_price::numeric / f.total_area::numeric),2) as min_cost_meter,
ROUND(MAX(a.last_price::numeric / f.total_area::numeric),2) as max_cost_meter
from real_estate.flats f 
join real_estate.advertisement a USING(id)
join real_estate.city c USING(city_id)
where c.city <> 'Санкт-Петербург' and id IN(
											SELECT * FROM filtered_id 
)
group by c.city 
having COUNT(a.days_exposition) > 0 and count(id) >50 --более 50 объявлений
order by duration_desk
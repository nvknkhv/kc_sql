--Примените оконные функции к таблице products и с помощью ранжирующих функций упорядочьте 
--все товары по цене — от самых дорогих к самым дешёвым. Добавьте в таблицу следующие колонки:

--Колонку product_number с порядковым номером товара (функция ROW_NUMBER).
--Колонку product_rank с рангом товара с пропусками рангов (функция RANK).
--Колонку product_dense_rank с рангом товара без пропусков рангов (функция DENSE_RANK)


--10.2
--для каждой записи проставьте цену самого дорогого товара, 
--для каждого товара посчитайте долю его цены в стоимости самого дорогого товара



-- 10.4
-- вычисление максимальной и минимальной цены

SELECT  product_id,
        name, 
        price,
        MAX(price) OVER(ORDER BY price DESC) as max_price,
        MAX(price) OVER() as max_price_without_order,    --без order by рамка - вся таблица
        MIN(price) OVER(ORDER BY price DESC) as min_price,
        MIN(price) OVER() as min_price_without_order
FROM products
ORDER BY price DESC, product_id


-- 10.5
-- накопительная сумма заказов по дням

with cte AS (
    SELECT DATE(creation_time) as date,
            COUNT(order_id) as orders_count
    FROM orders
    WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions
        WHERE action = 'cancel_order'
    )
    GROUP by date)
SELECT  date, 
        orders_count,
        SUM(orders_count) OVER (ORDER BY date)::integer as orders_count_cumulative
FROM cte


-- 10.6
-- для каждого пользователя в таблице user_actions посчитайте порядковый номер каждого заказа
-- для этого примените оконную функцию ROW_NUMBER к колонке с временем заказа
-- учитываются только неотмененные заказы

SELECT  user_id,
        order_id, 
        time,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) as order_number
FROM user_actions
WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions
        WHERE action = 'cancel_order'
)
ORDER BY user_id, order_id
LIMIT 1000

-- 10.7
-- дополните запрос из предыдущего задания и 
-- с помощью оконной функции для каждого заказа каждого пользователя рассчитайте сколько времени прошло с момента предыдущего заказа
SELECT  user_id,
        order_id, 
        time,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) as order_number,
        LAG(time, 1) OVER (PARTITION BY user_id ORDER BY time) as time_lag,
        (time - LAG(time, 1) OVER (PARTITION BY user_id ORDER BY time) ) as time_diff
FROM user_actions
WHERE order_id NOT IN (
        SELECT order_id 
        FROM user_actions
        WHERE action = 'cancel_order'
)
ORDER BY user_id, order_id
LIMIT 1000


-- 10.8
-- на основе запроса из предыдущего задания для каждого пользователя рассчитайте, сколько в среднем времени проходит между его заказами. 
-- учитывайте только для тех пользователей, которые за всё время оформили более одного неотмененного заказа.
-- среднее время между заказами выразите в часах

with cte as (SELECT user_id,
                    order_id,
                    time,
                    row_number() OVER (PARTITION BY user_id
                                       ORDER BY time) as order_number,
                    (time - lag(time, 1) OVER (PARTITION BY user_id
                                               ORDER BY time)) as time_diff,
                    extract(epoch
             FROM   (time - lag(time, 1)
             OVER (
             PARTITION BY user_id
             ORDER BY time)))/3600 as hours_between_orders
             FROM   user_actions
             WHERE  order_id not in (SELECT order_id
                                     FROM   user_actions
                                     WHERE  action = 'cancel_order')
                and user_id in (SELECT user_id
                             FROM   user_actions
                             GROUP BY user_id having(count(order_id) > 1)))
SELECT user_id,
       avg(hours_between_orders)::integer as hours_between_orders
FROM   cte
WHERE  time_diff is not null
GROUP BY user_id
ORDER BY user_id limit 1000


-- 10.9
-- cкользящее среднее по трем предыдущим строкам

with cte as (SELECT date(creation_time) as date,
                    count(order_id) as orders_count
             FROM   orders
             WHERE  order_id not in (SELECT order_id
                                     FROM   user_actions
                                     WHERE  action = 'cancel_order')
             GROUP BY date(creation_time))
SELECT date,
       orders_count,
       ROUND(AVG(orders_count) OVER (ORDER BY date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING ),2) as moving_avg
FROM   cte



-- 10.10
-- курьеры, которые доставили в сентябре 2022 года заказов больше, чем в среднем все курьеры

-- можно вынести courier_id и COUNT(order_id) в подзапрос
SELECT  courier_id, 
        COUNT(order_id) as delivered_orders,
        ROUND(AVG(COUNT(order_id)) OVER (), 2) as avg_delivered_orders,
        CASE 
            WHEN COUNT(order_id) > ROUND(AVG(COUNT(order_id)) OVER (), 2) 
            THEN 1 
            ELSE 0
        END as is_above_avg
        
FROM courier_actions
WHERE   action = 'deliver_order'
        AND EXTRACT(MONTH from time) = 9
GROUP BY courier_id  


-- 10.11
-- расчет первых и повторных заказов на каждую дату 
-- попробуем с помощью оконных функций и конструкции CASE посчитать сразу в одном запросе и те, и другие, не применяя JOIN

WITH cte AS (
    SELECT  DATE(time) as date,
            CASE 
            WHEN ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY time) = 1
            THEN 'Первый'
            ELSE 'Повторный'
            END as type
    FROM user_actions
    WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
    )
SELECT  date,   
        type as order_type,
        COUNT(type) as orders_count
FROM cte
GROUP BY date, type
ORDER BY date, type
    

-- Вариант верного решения:

SELECT time::date as date,
       order_type,
       count(order_id) as orders_count
FROM   (SELECT user_id,
               order_id,
               time,
               case when time = min(time) OVER (PARTITION BY user_id) then 'Первый'
                    else 'Повторный' end as order_type
        FROM   user_actions
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) t
GROUP BY date, order_type
ORDER BY date, order_type


-- 10.11
--  плюс посчитать долю заказов (на основе предыдущего запроса)
SELECT date,
       order_type,
       count(order_id) as orders_count,
       ROUND(   count(order_id)/
                SUM(count(order_id)) OVER(PARTITION BY date)
            , 2) as orders_share
FROM   (SELECT user_id,
               order_id,
               DATE(time) as date,
               case when time = min(time) OVER (PARTITION BY user_id) then 'Первый'
                    else 'Повторный' end as order_type
        FROM   user_actions
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) t
GROUP BY date, order_type
ORDER BY date, order_type

-- Вариант верного решения:

SELECT date,
       order_type,
       orders_count,
       round(orders_count / sum(orders_count) OVER (PARTITION BY date),
             2) as orders_share
FROM   (SELECT time::date as date,
               order_type,
               count(order_id) as orders_count
        FROM   (SELECT user_id,
                       order_id,
                       time,
                       case when time = min(time) OVER (PARTITION BY user_id) then 'Первый'
                            else 'Повторный' end as order_type
                FROM   user_actions
                WHERE  order_id not in (SELECT order_id
                                        FROM   user_actions
                                        WHERE  action = 'cancel_order')) t
        GROUP BY date, order_type) t
ORDER BY date, order_type


-- 10.13
-- средняя цену всех товаров. Колонку с этим значением назовите avg_price.
-- с помощью оконной функции и оператора FILTER рассчитайте среднюю цену товаров без учёта самого дорогого

with cte AS (
    SELECT  product_id,
            name,
            price,
            AVG(price) OVER() as avg_price
    FROM products 
)
SELECT  product_id,
        name,
        price,
        ROUND(avg_price, 2) as avg_price,
        ROUND(AVG(price) FILTER (WHERE price != (SELECT MAX(price) FROM cte)) OVER (), 2) as avg_price_filtered
FROM cte        
ORDER BY price DESC, product_id      


-- 10.14


-- 10.15
-- Из таблицы courier_actions отберите топ 10% курьеров по количеству доставленных за всё время заказов

WITH    cte AS (
            SELECT  courier_id,
                    COUNT(order_id) as orders_count
            FROM courier_actions
            WHERE action = 'deliver_order'
            GROUP BY courier_id),
        courier_count as 
            (SELECT count(distinct courier_id)
            FROM   courier_actions)
        
SELECT * FROM (
            SELECT  courier_id,
                    orders_count,
                    ROW_NUMBER() OVER(ORDER BY orders_count DESC, courier_id) as courier_rank   -- ранги по кол-ву заказов
            FROM cte) as t1
WHERE  courier_rank <= round((SELECT * 
                              FROM   courier_count)*0.1)    --общее число курьеров


-- 10.16
-- из таблицы courier_actions всех курьеров, которые работают в нашей компании 10 и более дней
-- сколько заказов они уже успели доставить за всё время работы
-- число дней, которые отработал курьер, — это количество дней, прошедших с первого принятого заказа до времени последней записи в таблице courier_actions


WITH max_time AS (-- верхняя отметка времени - макс time по всем действиям
    SELECT MAX(time)
    FROM courier_actions
    )

SELECT  courier_id,
        MAX(days_employed) as days_employed,
        MAX(delivered_orders) as delivered_orders
FROM (
    SELECT  courier_id,
            DATE_PART('days', 
                (SELECT * FROM max_time ) 
                - MIN(time) FILTER(WHERE action = 'accept_order') OVER(PARTITION BY courier_id  ORDER BY time))::int  as days_employed,     -- минимум по времени из только ПРИНЯТЫХ 
            COUNT(order_id) FILTER(WHERE action = 'deliver_order') OVER(PARTITION BY courier_id) as delivered_orders  -- только ДОСТАВЛЕННЫЕ
    FROM courier_actions
    -- в итоге будет таблица где для каждого курьера будут колонки с днями и count, число строк = число строк в исход таблице, то есть есть дубли
    ) as t
GROUP BY courier_id, days_employed
HAVING days_employed >=10
ORDER BY days_employed DESC, courier_id

Вариант верного решения:

SELECT courier_id,
       days_employed,
       delivered_orders
FROM   (SELECT courier_id,
               delivered_orders,
               date_part('days', max(max_time) OVER() - min_time)::integer as days_employed
        FROM   (SELECT courier_id,
                       count(distinct order_id) filter (WHERE action = 'deliver_order') as delivered_orders,
                       min(time) as min_time,
                       max(time) as max_time
                FROM   courier_actions
                GROUP BY courier_id) t1) t2
WHERE  days_employed >= 10
ORDER BY days_employed desc, courier_id






-- 10.17
-- На основе информации в таблицах orders и products рассчитайте стоимость каждого заказа, 
-- ежедневную выручку сервиса и долю стоимости каждого заказа в ежедневной выручке, выраженную в процентах
with orders_prices_days AS (
    SELECT  order_id,
            SUM(price) as order_price,
            DATE(MAX(creation_time)) as date
    FROM (
        SELECT  order_id, 
                UNNEST(product_ids) AS product_id,
                creation_time
        FROM orders AS unnest_orders) AS t2
    JOIN products
    USING(product_id) -- имеем таблицу order_id, product_id, price
    GROUP BY(order_id)
)
SELECT  order_id, 
        creation_time, 
        order_price,
        SUM(order_price) OVER(PARTITION BY date) as daily_revenue,
        ROUND(100 *order_price::decimal /  SUM(order_price) OVER(PARTITION BY date), 3) as percentage_of_daily_revenue
FROM orders
JOIN orders_prices_days
USING(order_id)
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
ORDER BY date DESC, percentage_of_daily_revenue DESC, order_id





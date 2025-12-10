-- 8.2
-- объедините таблицы user_actions и users по ключу user_id
-- eсли имя поля, по которому происходит объединение, совпадает в обеих таблицах, то можно использовать сокращенную запись c оператором USING

SELECT  ua.user_id as user_id_left,
        u.user_id as user_id_right,
        order_id,
        time, 
        action, 
        u.sex, 
        u.birth_date
FROM user_actions as ua
        JOIN users as u
        USING(user_id)
ORDER BY user_id     


-- 8.3
-- количество уникальных id в объединённой таблице

SELECT  COUNT(DISTINCT ua.user_id) as users_count
FROM user_actions as ua
        JOIN users as u
        USING(user_id)   


-- 8.4
--объедините таблицы user_actions и users по ключу user_id через LEFT JOIN + сортировка по id из левой таблицы

SELECT  ua.user_id as user_id_left,
        u.user_id as user_id_right,
        order_id,
        time, 
        action, 
        u.sex, 
        u.birth_date
FROM user_actions as ua
        LEFT JOIN users as u
        USING(user_id)
ORDER BY user_id_left


-- 8.5

SELECT  COUNT (DISTINCT ua.user_id) as users_count
FROM user_actions as ua
        LEFT JOIN users as u
        USING(user_id)


-- 8.6
--добавьте к запросу оператор WHERE и исключите NULL значения в колонке user_id из правой таблицы

SELECT ua.user_id as user_id_left,
       u.user_id as user_id_right,
       order_id,
       time,
       action,
       u.sex,
       u.birth_date
FROM   user_actions as ua
    LEFT JOIN users as u using(user_id)
WHERE  u.user_id is not null
ORDER BY user_id_left



-- 8.7
-- FULL JOIN

SELECT  a.birth_date as users_birth_date, 
        a.users_count as users_count,  
        b.birth_date as couriers_birth_date, 
        b.couriers_count as couriers_count
    FROM ( 
        SELECT  birth_date, 
                COUNT(user_id) AS users_count 
        FROM users 
        WHERE birth_date IS NOT NULL 
        GROUP BY birth_date 
    ) a 
    FULL JOIN ( 
        SELECT  birth_date, 
                COUNT(courier_id) AS couriers_count 
        FROM couriers 
        WHERE birth_date IS NOT NULL 
        GROUP BY birth_date 
    ) b 
    USING(birth_date) 
    ORDER BY users_birth_date, couriers_birth_date


-- 8.8
/* 
Операция UNION объединяет записи из двух запросов в один общий результат (объединение множеств).

Операция EXCEPT возвращает все записи,которые есть в первом запросе,но отсутствуют во втором
(разница множеств)

Операция INTERSECT возвращает все записи,которые есть и в первом,и во втором запросе (пересечение множеств).

При этом по умолчанию эти операции исключают из результата строки-дубликаты. Чтобы дубликаты не исключались 
из результата, необходимо после имени операции указать ключевое слово ALL
*/

--  набор уникальных дат из таблиц users и couriers
SELECT COUNT(birth_date) as dates_count
FROM (SELECT birth_date
FROM users WHERE birth_date IS NOT NULL
UNION 
SELECT birth_date couriers 
FROM couriers WHERE birth_date IS NOT NULL) as t   


-- 8.9
-- из таблицы users отберите id первых 100 пользователей (просто выберите первые 100 записей, 
-- используя простой LIMIT)
-- и с помощью CROSS JOIN объедините их со всеми наименованиями товаров из таблицы products

-- вариант верного
SELECT user_id,
       name
FROM   (SELECT user_id
        FROM   users limit 100) t1 cross join (SELECT name
                                       FROM   products) t2
ORDER BY user_id, name

-- еще один
SELECT u.user_id as user_id,
       p.name as name
FROM   products as p cross join (SELECT user_id
                                 FROM   users limit 100) as u
ORDER BY user_id, name


-- 8.10
SELECT  user_id,
        order_id,
        o.product_ids
FROM user_actions as ua
LEFT JOIN orders as o
USING (order_id)
ORDER BY user_id, order_id
LIMIT 1000


-- 8.11
-- объедините таблицы user_actions и orders, но теперь оставьте только уникальные неотменённые заказы

SELECT user_id,
       order_id,
       product_ids
FROM   (SELECT user_id,
               order_id
        FROM   user_actions
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) t
    LEFT JOIN orders using(order_id)
ORDER BY user_id, order_id limit 1000


-- 8.12
-- сколько в среднем товаров заказывает каждый пользователь

SELECT user_id,
       ROUND(AVG(array_length(product_ids, 1)), 2) as avg_order_size
FROM   (SELECT user_id,
               order_id
        FROM   user_actions
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) as t
LEFT JOIN orders using(order_id)
GROUP BY user_id
ORDER BY user_id limit 1000

-- 8.13
-- к orders примените функцию unnest => будет таблица номер заказа - номер товара
-- затем к образовавшейся расширенной таблице по ключу product_id добавьте информацию о ценах на товары (из таблицы products)
-- должна получиться таблица с заказами, товарами внутри каждого заказа и ценами на эти товары
SELECT order_id,
       product_id,
       p.price
FROM   (SELECT order_id,
               unnest(product_ids) as product_id
        FROM   orders) as o
    LEFT JOIN products as p using (product_id)
ORDER BY order_id, product_id limit 1000


-- 8.14
-- стоимость каждого заказа
SELECT  order_id, 
        SUM(p.price) as order_price
FROM (
    SELECT  order_id, 
            unnest(product_ids) as product_id
    FROM orders        
) as o     
LEFT JOIN products as p
USING (product_id)
GROUP BY order_id
ORDER BY order_id
LIMIT 1000

-- 8.15
 --для каждого пользователя рассчитайте следующие показатели:
    -- общее число заказов — колонку назовите orders_count
    -- среднее количество товаров в заказе — avg_order_size
    -- суммарную стоимость всех покупок — sum_order_value
    -- среднюю стоимость заказа — avg_order_value
    -- минимальную стоимость заказа — min_order_value
    -- максимальную стоимость заказа — max_order_value
WITH orders_with_price AS (
        SELECT  order_id, 
                SUM(price) as order_price
        FROM (
            SELECT  order_id, 
                    unnest(product_ids) as product_id
            FROM orders        
        ) as o     
        LEFT JOIN products as p
        USING (product_id)
        GROUP BY order_id
        ),
    orders_by_user AS 
        (
        SELECT user_id,
               product_ids,
               order_id
        FROM   (SELECT user_id,
                       order_id
                FROM   user_actions
                WHERE  order_id not in (SELECT order_id
                                        FROM   user_actions
                                        WHERE  action = 'cancel_order')) as t
            LEFT JOIN orders using(order_id)
        )
select  user_id,
        COUNT(order_id) as orders_count,
        round(avg(array_length(product_ids, 1)), 2) as avg_order_size,
        SUM(order_price) as sum_order_value,
        round(AVG(order_price), 2) as avg_order_value,
        round(MIN(order_price), 2) as min_order_value,
        round(MAX(order_price), 2) as max_order_value
from  orders_by_user
    LEFT JOIN orders_with_price
    USING (order_id)
GROUP BY (user_id)    
ORDER BY user_id
LIMIT 1000


-- 8.16
-- ежедневная выручка сервиса

WITH t AS (
        SELECT * FROM (
                        SELECT order_id,
                            unnest(product_ids) as product_id,
                            creation_time
                        FROM orders
                        WHERE order_id NOT IN (
                            SELECT order_id 
                            FROM user_actions
                            WHERE action = 'cancel_order')
                        ) as unnest
                JOIN products as p
                USING(product_id)
    
)
SELECT  DATE(creation_time) as date,
        SUM(price) as revenue
FROM t
GROUP BY (DATE(creation_time))
ORDER BY date


-- 8.17
-- по таблицам courier_actions , orders и products 
-- определите 10 самых популярных товаров, доставленных в сентябре 2022 года

SELECT name,
       times_purchased
FROM   (SELECT unnest(product_ids) as product_id,
               count(distinct order_id) as times_purchased
        FROM   orders
        WHERE  order_id in (SELECT order_id
                            FROM   courier_actions
                            WHERE  action = 'deliver_order'
                               and date_part('month', time) = 9
                               and date_part('year', time) = 2022)
        GROUP BY product_id
        ORDER BY times_purchased desc limit 10) as t1
    LEFT JOIN products using(product_id)
ORDER BY times_purchased desc limit 10


-- 8.18
-- посчитайте среднее значение cancel_rate для каждого пола

with cancel_rate_by_user as (SELECT user_id,
                                    (count(order_id) filter (WHERE action = 'cancel_order'))::decimal / (count(order_id) filter (WHERE action = 'create_order')) as cancel_rate
                             FROM   user_actions
                             GROUP BY user_id)
SELECT coalesce(sex, 'unknown') as sex,
       round(avg(cancel_rate), 3) as avg_cancel_rate
FROM   cancel_rate_by_user
    LEFT JOIN users using(user_id)
GROUP BY sex
ORDER BY sex


-- 8.19
-- по таблицам orders и courier_actions определите id десяти заказов, которые доставляли дольше всего.
with cte as (SELECT order_id,
                    time - creation_time as time_diff
             FROM   orders
                 LEFT JOIN courier_actions using(order_id))
SELECT order_id
FROM   cte
ORDER BY time_diff desc limit 10


Вариант верного решения:

SELECT order_id
FROM   (SELECT order_id,
               time as delivery_time
        FROM   courier_actions
        WHERE  action = 'deliver_order') as t
    LEFT JOIN orders using (order_id)
ORDER BY delivery_time - creation_time desc limit 10       





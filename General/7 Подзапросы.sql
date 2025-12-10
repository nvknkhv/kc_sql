 /*
 Подзапросы могут применяться в следующих частях основного запроса:
- в операторе FROM (для подзапроса нужен alias);
- в операторе SELECT (если запрос возвращает один столбец с одним значением);
- в операторах WHERE и HAVING (если запрос возвращает один столбец с одним или несколькими значениями);
- в операторе CASE при формировании продвинутых условных конструкций
*/

-- 7.2
-- avg кол-ва созданных заказов по всем пользователям

SELECT ROUND(AVG(orders_cnt), 2) as  orders_avg
FROM (
    SELECT user_id,
        COUNT(order_id) as orders_cnt
    FROM user_actions
    WHERE action = 'create_order'
    GROUP BY user_id
) as t1


-- 7.3
-- то же самое через cte (common table expression)

WITH t1 as (
    SELECT user_id,
        COUNT(order_id) as orders_cnt
    FROM user_actions
    WHERE action = 'create_order'
    GROUP BY user_id
)
SELECT ROUND(AVG(orders_cnt), 2) as  orders_avg
FROM t1


-- 7.4
-- информацию о всех товарах кроме самого дешёвого

SELECT  product_id,
        name,
        price
FROM    products  
WHERE price != (SELECT MIN(price) from products) 
ORDER BY product_id DESC 


-- 7.5
-- немного другой вариант, когда подзапрос с AVG(price) вынесли из запроса как переменную
-- важно, что обратиться к AVG(price) нужно через select * from - как к таблице, а не просто как к значению

WITH avg_price as (
    SELECT AVG(price) from products
)
SELECT  product_id,
        name, 
        price
FROM products
WHERE (price - (SELECT * FROM avg_price)) >= 20  
ORDER BY product_id DESC


-- 7.6
-- количество уникальных клиентов в таблице user_actions, 
-- сделавших за последнюю неделю хотя бы один заказ

/* Например, от текущей даты можно отнять заданный промежуток INTERVAL:

    SELECT NOW() - INTERVAL '1 year 2 months 1 week'

   --Результат:
    --10/10/21 19:32

*/

SELECT count(distinct user_id) as users_count
FROM   user_actions
WHERE  action = 'create_order'
   and time >= (SELECT max(time)
             FROM   user_actions) - interval '1 week'


-- 7.7
-- возраст самого молодого курьера мужского пола в таблице couriers, 
-- в качестве первой даты используйте последнюю дату из таблицы courier_actions 
    
SELECT MIN(AGE(
            (SELECT MAX(time)::DATE from courier_actions), 
            birth_date))
        ::varchar as min_age
FROM couriers
WHERE sex = 'male'


-- 7.8
-- созданные и неотмененные заказы

SELECT order_id
FROM user_actions
WHERE order_id NOT IN (
    SELECT order_id FROM user_actions WHERE action = 'cancel_order'
)
ORDER BY order_id
LIMIT 1000


-- 7.9
-- сколько заказов сделал каждый пользователь
-- среднее число заказов всех пользователей
-- (отклонение числа заказов от среднего значения) число заказов «минус» округлённое среднее значение

with created_orders_by_user AS (
  SELECT    user_id,
            COUNT(order_id) as orders_count
    FROM user_actions
    WHERE action='create_order'
    GROUP BY user_id
)
SELECT  user_id,
        orders_count,
        ROUND((SELECT AVG(orders_count) FROM created_orders_by_user), 2) as orders_avg,
        (orders_count - ROUND((SELECT AVG(orders_count) FROM created_orders_by_user), 2)) as orders_diff
FROM created_orders_by_user
ORDER BY user_id
LIMIT 1000  


-- 7.10
-- назначьте скидку 15% на товары, цена которых превышает среднюю цену на все товары на 50 и более рублей, 
-- а также скидку 10% на товары, цена которых ниже средней на 50 и более рублей
-- цену остальных товаров внутри диапазона (среднее - 50; среднее + 50) оставьте без изменений

with avg_price as (SELECT avg(price)
                   FROM   products)
SELECT product_id,
       name,
       price,
       round(case when (price - (SELECT *
                          FROM   avg_price)) >= 50 then 0.85*price when ((SELECT *
                                                FROM   avg_price) - price) >= 50 then 0.9*price else price end , 2) as new_price
FROM   products
ORDER BY price desc, product_id


-- 7.11
-- заказы, которые были приняты курьерами, но не были созданы пользователями

SELECT count (distinct order_id) as orders_count
FROM   courier_actions
WHERE  action = 'accept_order'
   and order_id not in (SELECT order_id
                     FROM   user_actions
                     WHERE  action = 'create_order')



-- 7.12
-- заказы пользователей, которые были приняты курьером, но не были доставлены

SELECT count(distinct order_id) as orders_count
FROM   user_actions
WHERE  order_id in (SELECT order_id
                    FROM   courier_actions
                    WHERE  action = 'accept_order')
   and order_id not in (SELECT order_id
                     FROM   courier_actions
                     WHERE  action = 'deliver_order')    


-- 7.13
-- отменены пользователями
-- отменены пользователями, но при этом всё равно были доставлены 

SELECT count(distinct order_id) as orders_canceled,
       count(order_id) filter (WHERE action = 'deliver_order') as orders_canceled_and_delivered
FROM   courier_actions
WHERE  order_id in (SELECT order_id
                    FROM   user_actions
                    WHERE  action = 'cancel_order')       


-- 7.14  
-- число недоставленных заказов и среди них посчитайте 
-- количество отменённых заказов и количество заказов, которые не были отменены 

SELECT count(distinct order_id) as orders_undelivered,
       count(order_id) filter (WHERE action = 'cancel_order') as orders_canceled,
       count(distinct order_id) - count(order_id) filter (WHERE action = 'cancel_order') as orders_in_process
FROM   user_actions
WHERE  order_id NOT IN (SELECT order_id
                    FROM   courier_actions
                    WHERE  action = 'deliver_order')                                     


-- 7.15
-- пользователей мужского пола, которые старше всех пользователей женского пола
-- мое:
with max_female_age as (SELECT max(age(birth_date))
                        FROM   users
                        WHERE  sex = 'female')
SELECT user_id,
       birth_date
FROM   users
WHERE  sex = 'male'
   and age(birth_date) > (SELECT *
                       FROM   max_female_age)
ORDER BY user_id

-- вариант верного
SELECT user_id,
       birth_date
FROM   users
WHERE  sex = 'male'
   and birth_date < (SELECT min(birth_date)
                  FROM   users
                  WHERE  sex = 'female')
ORDER BY user_id


-- 7.16
-- id и содержимое 100 последних доставленных заказов из таблицы orders

SELECT order_id,
        product_ids
FROM  orders
WHERE order_id IN (
    SELECT order_id from courier_actions
    WHERE action = 'deliver_order'
    ORDER BY time desc limit 100
)
ORDER BY order_id


-- 7.17
-- всю информацию о курьерах, которые в сентябре 2022 года доставили 30 и более заказов

SELECT courier_id,
        birth_date,
        sex
FROM couriers
WHERE courier_id IN (
            SELECT courier_id
            FROM courier_actions
            WHERE date_part('month', time) = 9 and date_part('year', time) = 2022
                    AND action = 'deliver_order'
            GROUP BY (courier_id)
            HAVING COUNT(order_id) >= 30
)
ORDER BY  courier_id      


-- 7.18
-- средний размер заказов, отменённых пользователями мужского пола

SELECT ROUND(AVG(array_length(product_ids, 1)), 3) as avg_order_size
FROM orders
WHERE order_id IN (
            SELECT order_id FROM user_actions WHERE action = 'cancel_order'
                                                    and user_id IN (
                                                        SELECT user_id FROM users WHERE sex = 'male'
                                                    )
            )


-- 7.19        
-- посчитайте возраст каждого пользователя в таблице users
-- возраст измерьте числом полных лет
-- возраст считайте относительно последней даты в таблице user_actions
-- для тех пользователей, у которых в таблице users не указана дата рождения, 
-- укажите среднее значение возраста всех остальных пользователей, округлённое до целого числа

with users_age as (SELECT user_id,
                          date_part('year', age((SELECT max(time)
                                          FROM   user_actions), birth_date)) as age
                   FROM   users)
SELECT user_id,
       coalesce(age, (SELECT round(avg(age))
               FROM   users_age))::integer as age
FROM   users_age
ORDER BY user_id


-- 7.20
-- для каждого заказа, в котором больше 5 товаров, рассчитайте время, затраченное на его доставку
-- в расчётах учитывайте только неотменённые заказы
-- время, затраченное на доставку, выразите в минутах, округлив значения до целого числа
  
SELECT order_id,
       min(time) as time_accepted,
       max(time) as time_delivered,
       (extract(epoch
FROM   max(time) - min(time))/60)::integer as delivery_time
FROM   courier_actions
WHERE  order_id in (SELECT DISTINCT order_id
                    FROM   orders
                    WHERE  array_length(product_ids, 1) > 5)
   and order_id not in (SELECT order_id
                     FROM   user_actions
                     WHERE  action = 'cancel_order')
GROUP BY order_id
ORDER BY order_id


-- 7.21
-- для каждой даты в таблице user_actions посчитайте количество первых заказов, совершённых пользователями
-- первыми заказами будем считать заказы, которые пользователи сделали в нашем сервисе впервые
-- в расчётах учитывайте только неотменённые заказы

with by_user as (SELECT user_id,
                        date(min(time)) as date
                 FROM   user_actions
                 WHERE  order_id not in (SELECT order_id
                                         FROM   user_actions
                                         WHERE  action = 'cancel_order')
                 GROUP BY user_id)
SELECT date,
       count(user_id) as first_orders
FROM   by_user
GROUP BY date
ORDER BY date


--7.22
--функция unnest предназначена для разворачивания массивов и превращения их в набор строк

SELECT creation_time,
       order_id,
       product_ids,
       unnest(product_ids) as product_id
FROM   orders limit 100

-- 7.23
-- определите 10 самых популярных товаров 
    
SELECT * FROM(SELECT unnest(product_ids) as product_id,
                     count(*) as times_purchased
              FROM   orders
              WHERE  order_id not in (SELECT order_id
                                      FROM   user_actions
                                      WHERE  action = 'cancel_order')
              GROUP BY product_id
              ORDER BY times_purchased desc limit 10) as t1
ORDER BY product_id


--7.24
--выведите id и содержимое заказов, которые включают хотя бы один из пяти самых дорогих товаров

with top_products as (SELECT product_id
                      FROM   products
                      ORDER BY price desc limit 5), 
    unnest as (SELECT order_id,
        product_ids,
        unnest(product_ids) as product_id
        FROM   orders)
SELECT DISTINCT order_id,
                product_ids
FROM   unnest
WHERE  product_id in (SELECT *
                      FROM   top_products)
ORDER BY order_id





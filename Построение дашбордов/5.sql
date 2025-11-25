-- 1.5
/* 
Для каждого дня, представленного в таблице user_actions, рассчитайте следующие показатели:

- Общее число заказов.
- Число первых заказов (заказов, сделанных пользователями впервые).
- Число заказов новых пользователей (заказов, сделанных пользователями в тот же день, когда они впервые воспользовались сервисом).
- Долю первых заказов в общем числе заказов (долю п.2 в п.1).
- Долю заказов новых пользователей в общем числе заказов (долю п.3 в п.1).

*/

WITH created_orders AS (
        SELECT * 
        FROM user_actions
        WHERE action = 'create_order' AND order_id NOT IN (SELECT order_id FROM user_actions
                                                            WHERE action = 'cancel_order')
    ),
    
    -- даты первого ЛЮБОГО действия пользователя
    user_first_action AS (
        SELECT  user_id,
                MIN(time::date) as first_action_date
        --  по всем действиям       
        FROM user_actions      
        GROUP BY user_id
    ),
    
    -- даты первого действия СОЗДАНИЯ ЗАКАЗА пользователя
    user_first_action_created AS (
        SELECT  user_id,
                MIN(time::date) as first_create_date
        --  по созданным и неотмененым заказам      
        FROM created_orders      
        GROUP BY user_id
    ),
    

    new_users_orders AS (
        SELECT  co.user_id as user_id,
                COUNT(DISTINCT order_id) as first_orders_cnt,
                time::date as date
        FROM created_orders as co
        LEFT JOIN user_first_action AS ufa
        ON co.user_id = ufa.user_id
        -- выбираем заказы с датой заказа = дата первого действия
        WHERE co.time::date = ufa.first_action_date
        GROUP BY time, co.user_id
    ),
    
    general_orders_cnt_by_date AS (
        SELECT  time::date as date,
            COUNT(order_id) as orders_cnt
        FROM created_orders
        GROUP BY time::date
        ),
    
    first_orders_cnt_by_date AS (
        SELECT  first_create_date as date,
            COUNT(DISTINCT user_id) as first_orders_cnt
        FROM user_first_action_created
        GROUP BY first_create_date
        ),
        
    new_users_orders_cnt_by_date AS (
        SELECT  date,
                SUM(first_orders_cnt) as new_users_orders_cnt
        FROM new_users_orders
        GROUP BY date
        )    
        
SELECT  date,
        orders_cnt::int AS orders,
        first_orders_cnt::int AS first_orders,
        new_users_orders_cnt::int AS new_users_orders,
        ROUND (100 * first_orders_cnt::decimal / orders_cnt, 2) AS first_orders_share,
        ROUND (100 * new_users_orders_cnt::decimal / orders_cnt, 2) AS new_users_orders_share
FROM new_users_orders_cnt_by_date
JOIN first_orders_cnt_by_date
USING(date)
JOIN general_orders_cnt_by_date
USING(date)   
ORDER BY date










-- Вариант верного решения:
SELECT date,
       orders,
       first_orders,
       new_users_orders::int,
       round(100 * first_orders::decimal / orders, 2) as first_orders_share,
       round(100 * new_users_orders::decimal / orders, 2) as new_users_orders_share
FROM   (SELECT creation_time::date as date,
               count(distinct order_id) as orders
        FROM   orders
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')
           and order_id in (SELECT order_id
                         FROM   courier_actions
                         WHERE  action = 'deliver_order')
        GROUP BY date) t5
    LEFT JOIN (SELECT first_order_date as date,
                      count(user_id) as first_orders
               FROM   (SELECT user_id,
                              min(time::date) as first_order_date
                       FROM   user_actions
                       WHERE  order_id not in (SELECT order_id
                                               FROM   user_actions
                                               WHERE  action = 'cancel_order')
                       GROUP BY user_id) t4
               GROUP BY first_order_date) t7 using (date)
    LEFT JOIN (SELECT start_date as date,
                      sum(orders) as new_users_orders
               FROM   (SELECT t1.user_id,
                              t1.start_date,
                              coalesce(t2.orders, 0) as orders
                       FROM   (SELECT user_id,
                                      min(time::date) as start_date
                               FROM   user_actions
                               GROUP BY user_id) t1
                           LEFT JOIN (SELECT user_id,
                                             time::date as date,
                                             count(distinct order_id) as orders
                                      FROM   user_actions
                                      WHERE  order_id not in (SELECT order_id
                                                              FROM   user_actions
                                                              WHERE  action = 'cancel_order')
                                      GROUP BY user_id, date) t2
                               ON t1.user_id = t2.user_id and
                                  t1.start_date = t2.date) t3
               GROUP BY start_date) t6 using (date)
ORDER BY date   
    
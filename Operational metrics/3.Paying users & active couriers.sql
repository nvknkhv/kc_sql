-- 1.3
/*  
Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:

- Число платящих пользователей.
- Число активных курьеров.
- Долю платящих пользователей в общем числе пользователей на текущий день.
- Долю активных курьеров в общем числе курьеров на текущий день.

Платящий пользователь = в данный день оформил хотя бы один заказ, который в дальнейшем не был отменен.

Активный курьер = в данный день принял хотя бы один заказ, который был доставлен или доставил любой заказ.

Общее число пользователей/курьеров на текущий день — это по-прежнему результат сложения числа новых пользователей/курьеров в текущий день со значениями аналогичного показателя всех предыдущих дней. Мы считали этот показатель на предыдущих шагах.

*/

WITH users_first_actions AS (
    SELECT  user_id,
            MIN(time)::date as date
    FROM user_actions
    GROUP BY user_id
),

    couriers_first_actions AS (
    SELECT  courier_id,
            MIN(time)::date as date
    FROM courier_actions
    GROUP BY courier_id
),

    users_and_couriers_first_actions AS (
    SELECT * FROM users_first_actions
    JOIN couriers_first_actions
    USING(date)
),

    cancelled_orders AS (
        SELECT order_id
        FROM user_actions
        WHERE action = 'cancel_order'),
        
    users_paid_by_date AS (
        SELECT  time::date as date,
                COUNT(DISTINCT user_id) as paying_users
        FROM user_actions
        -- платящие - это пользователи, которые создали и не отменили заказы
        WHERE action = 'create_order' AND
                order_id NOT IN (SELECT * FROM cancelled_orders)
        GROUP BY time::date      
    ),
    
    delivered_orders AS (
        SELECT order_id
        FROM courier_actions
        WHERE action = 'deliver_order'
        ),
    
    couriers_active_by_date AS (
        SELECT  time::date as date,
                COUNT(DISTINCT courier_id) as active_couriers
        FROM courier_actions
        -- активные - это те курьеры, которые приняли хотя бы один доставленный заказ или доставили
        WHERE (action = 'accept_order' AND
                order_id IN (SELECT * FROM delivered_orders))
                OR (action = 'deliver_order')
        GROUP BY time::date      
        ),
    
    counts_by_date AS (
        SELECT * FROM (
                SELECT date,
                    COUNT(DISTINCT users_and_couriers_first_actions.user_id) as new_users,
                    COUNT(DISTINCT courier_id) as new_couriers
                FROM users_and_couriers_first_actions 
                GROUP BY date
                ) as t1
        JOIN users_paid_by_date
        USING(date) 
        JOIN couriers_active_by_date
        USING(date)    
        ORDER BY date
        ),
    
    metrics AS (
        SELECT  date,
            new_users,
            SUM(new_users) OVER (ORDER BY date)::int AS total_users,
            paying_users,
            new_couriers,
            SUM(new_couriers) OVER (ORDER BY date)::int AS total_couriers,
            active_couriers
        FROM counts_by_date)

    
SELECT  date,
        paying_users,
        ROUND (100 * paying_users::decimal / total_users, 2) as paying_users_share,
        active_couriers,
        ROUND (100 * active_couriers::decimal / total_couriers, 2) as several_orders_users_share
FROM metrics







-- Вариант верного решения:

SELECT date,
       paying_users,
       active_couriers,
       round(100 * paying_users::decimal / total_users, 2) as paying_users_share,
       round(100 * active_couriers::decimal / total_couriers, 2) as active_couriers_share
FROM   (SELECT start_date as date,
               new_users,
               new_couriers,
               (sum(new_users) OVER (ORDER BY start_date))::int as total_users,
               (sum(new_couriers) OVER (ORDER BY start_date))::int as total_couriers
        FROM   (SELECT start_date,
                       count(courier_id) as new_couriers
                FROM   (SELECT courier_id,
                               min(time::date) as start_date
                        FROM   courier_actions
                        GROUP BY courier_id) t1
                GROUP BY start_date) t2
            LEFT JOIN (SELECT start_date,
                              count(user_id) as new_users
                       FROM   (SELECT user_id,
                                      min(time::date) as start_date
                               FROM   user_actions
                               GROUP BY user_id) t3
                       GROUP BY start_date) t4 using (start_date)) t5
    LEFT JOIN (SELECT time::date as date,
                      count(distinct courier_id) as active_couriers
               FROM   courier_actions
               WHERE  order_id not in (SELECT order_id
                                       FROM   user_actions
                                       WHERE  action = 'cancel_order')
               GROUP BY date) t6 using (date)
    LEFT JOIN (SELECT time::date as date,
                      count(distinct user_id) as paying_users
               FROM   user_actions
               WHERE  order_id not in (SELECT order_id
                                       FROM   user_actions
                                       WHERE  action = 'cancel_order')
               GROUP BY date) t7 using (date)

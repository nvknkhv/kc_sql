-- 1.1

/*
Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитайте следующие показатели:
- Число новых пользователей.
- Число новых курьеров.
- Общее число пользователей на текущий день.
- Общее число курьеров на текущий день.

Новыми будем считать тех пользователей и курьеров, которые в данный день совершили своё первое действие в нашем сервисе.
*/

WITH users_first_actions AS (
    SELECT  user_id,
            MIN(time)::date as first_date
    FROM user_actions
    GROUP BY user_id
),
    couriers_first_actions AS (
    SELECT  courier_id,
            MIN(time)::date as first_date
    FROM courier_actions
    GROUP BY courier_id
),
    users_and_couriers_first_actions AS (
    SELECT * FROM users_first_actions
    JOIN couriers_first_actions
    USING(first_date)
),
    counts_by_date AS (
    SELECT  first_date as date,
        COUNT(DISTINCT user_id) as new_users,
        COUNT(DISTINCT courier_id) as new_couriers
    FROM users_and_couriers_first_actions
    GROUP BY first_date
    ORDER BY date
    )
    

SELECT  date,
        new_users,
        new_couriers,
        SUM(new_users) OVER (ORDER BY date)::int AS total_users,
        SUM(new_couriers) OVER (ORDER BY date)::int AS total_couriers
FROM counts_by_date










-- Вариант верного решения:

SELECT start_date as date,
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
               GROUP BY start_date) t4 using (start_date)
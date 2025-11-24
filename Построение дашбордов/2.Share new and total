-- 1.2
/* 
Дополните запрос из предыдущего задания и теперь для каждого дня, представленного в таблицах user_actions и courier_actions, дополнительно рассчитайте следующие показатели:

- Прирост числа новых пользователей.
- Прирост числа новых курьеров.
- Прирост общего числа пользователей.
- Прирост общего числа курьеров.
- Показатели, рассчитанные на предыдущем шаге, также включите в результирующую таблицу.

прирост = (новое значение - старое)/старое
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
    ),
    
    metrics AS (
    SELECT  date,
        new_users,
        new_couriers,
        SUM(new_users) OVER (ORDER BY date)::int AS total_users,
        SUM(new_couriers) OVER (ORDER BY date)::int AS total_couriers
FROM counts_by_date)
    
SELECT  date,
        new_users,
        new_couriers,
        total_users,
        total_couriers,
        --  прирост новых пользователей к предыдущему дню
        ROUND((new_users - LAG(new_users) OVER (ORDER BY date))*100::decimal / LAG(new_users) OVER (ORDER BY date), 2)  as new_users_change,
        
        ROUND((new_couriers - LAG(new_couriers) OVER (ORDER BY date))*100::decimal / LAG(new_couriers) OVER (ORDER BY date), 2)  as new_couriers_change,
        
        ROUND((total_users - LAG(total_users) OVER (ORDER BY date))*100::decimal / LAG(total_users) OVER (ORDER BY date), 2)  as total_users_growth,
        
        ROUND((total_couriers - LAG(total_couriers) OVER (ORDER BY date))*100::decimal / LAG(total_couriers) OVER (ORDER BY date), 2)  as total_couriers_growth
        
FROM metrics










-- Вариант верного решения:

SELECT date,
       new_users,
       new_couriers,
       total_users,
       total_couriers,
       round(100 * (new_users - lag(new_users, 1) OVER (ORDER BY date)) / lag(new_users, 1) OVER (ORDER BY date)::decimal,
             2) as new_users_change,
       round(100 * (new_couriers - lag(new_couriers, 1) OVER (ORDER BY date)) / lag(new_couriers, 1) OVER (ORDER BY date)::decimal,
             2) as new_couriers_change,
       round(100 * new_users::decimal / lag(total_users, 1) OVER (ORDER BY date),
             2) as total_users_growth,
       round(100 * new_couriers::decimal / lag(total_couriers, 1) OVER (ORDER BY date),
             2) as total_couriers_growth
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
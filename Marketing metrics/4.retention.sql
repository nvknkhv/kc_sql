SELECT  start_date,
        --action_date,
        --активные пользователи на текущую дату
        --COUNT(DISTINCT user_id) as active_users,      
        -- максимум пользовталей на текущую дату
        --MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY start_date)
        ROUND(COUNT(DISTINCT user_id)*1.0/ MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY start_date), 2) as retention,
        DATE_TRUNC('month', start_date)::date as start_month,
        action_date - start_date as day_number

FROM(  SELECT  user_id,
            time::date as action_date,
            MIN(time::date) OVER (PARTITION BY user_id) as start_date
    FROM user_actions  ) as t1   
GROUP BY action_date  , start_date
ORDER BY start_date, day_number






-- Вариант верного
SELECT date_trunc('month', start_date)::date as start_month,
       start_date,
       date - start_date as day_number,
       round(users::decimal / max(users) OVER (PARTITION BY start_date), 2) as retention
FROM   (SELECT start_date,
               time::date as date,
               count(distinct user_id) as users
        FROM   (SELECT user_id,
                       time::date,
                       min(time::date) OVER (PARTITION BY user_id) as start_date
                FROM   user_actions) t1
        GROUP BY start_date, time::date) t2
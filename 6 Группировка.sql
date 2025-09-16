-- 6.1
SELECT sex,
       count(courier_id) as couriers_count
FROM   couriers
GROUP BY sex
ORDER BY 2
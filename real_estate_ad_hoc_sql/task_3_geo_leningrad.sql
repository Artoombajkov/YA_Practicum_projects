with Limits AS (
    SELECT 
    	count(ID), 
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
)
select count(distinct a.id) as sum_id,
		count(days_exposition) as snyatie_s_publikacii,
		100*count(days_exposition)/count(distinct a.id) as dolya_snyatyh,
		round(avg(total_area)::numeric, 2) as srednya_ploshad,
		round(avg (last_price/total_area)::numeric, 2) as srednya_stoimost_KV_M,
		round(avg(days_exposition)) as dlitelnost_v_publ,
		city,
		type
from real_estate.advertisement a 
left join real_estate.flats f on a.id = f.id 
join real_estate.city c on f.city_id = c.city_id 
join real_estate.type t on f.type_id = t.type_id
where city != 'Санкт-Петербург' 
		and total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS null)
group by city,
		type
order by sum_id desc
limit 15
--Что можно улучшить Ранжировать в данном случае очень удобно с помощью ntile данная функция позволяет разделить данные на определенное число групп - это как раз удобно для заказчика, объединить данные, чтобы выбрать какие-либо стратегии по каждой из групп. -- не понял на счет этого запроса, необходимо ли это тут?
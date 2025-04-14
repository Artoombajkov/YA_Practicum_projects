WITH 
-- Убираю аномальные значения
Limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
Publication_month as (
	select count(A.id) as sum_publication,
		extract(month from first_day_exposition) as month_publication,
		round(100*count(A.id)::numeric/(select count (id) from real_estate.advertisement a ),2) as dolya_ot_obshih_publ,
		round(avg(total_area)::numeric,2) as sr_pl,
		round(avg(last_price/total_area)::numeric,2) as sp_cena_kvm
	from real_estate.advertisement a 
	JOIN
        real_estate.flats f ON a.id = f.id
    JOIN
        real_estate.type t ON f.type_id = t.type_id
    WHERE
        t.type = 'город' 
        and total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
	group by month_publication
),
Rank_publication as ( 
	select rank() over (order by sum_publication desc) as rank_month,
			month_publication,
			sum_publication,
			dolya_ot_obshih_publ,
			sr_pl,
			sp_cena_kvm
	from Publication_month
),
End_publicatoin as (
	select count(days_exposition) as end_sum_publication,
		extract(month from (make_interval(days => coalesce (days_exposition, 0)::INT) + first_day_exposition)::date) as month_end_publication,
		round(100*count(days_exposition)::numeric/(select count (id) from real_estate.advertisement a ),2) as dolya_end_ot_obshih_publ,
		round(avg(total_area)::numeric,2) as end_sr_pl,
		round(avg(last_price/total_area)::numeric,2) as end_sp_cena_kvm
	from real_estate.advertisement a 
	JOIN
        real_estate.flats f ON a.id = f.id
    JOIN
        real_estate.type t ON f.type_id = t.type_id
    WHERE
        t.type = 'город' 
        and total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
	group by month_end_publication
),
Rank_end_publicatoin as (
	select rank() over (order by end_sum_publication desc) as rank_month,
			month_end_publication,
			end_sum_publication,
			dolya_end_ot_obshih_publ,
			end_sr_pl,
			end_sp_cena_kvm
	from End_publicatoin
)
select *
from Rank_publication r
join rank_end_publicatoin e on r.month_publication = e.month_end_publication
order by month_publication
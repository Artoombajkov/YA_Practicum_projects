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
-- Нахожу id объявлений которые не содержат выбросы
Filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Делю на группы по времени снятия с публикации
TimeCategories AS (
    SELECT
        a.id,
        CASE
            WHEN a.days_exposition <= 30 THEN 'До 1 месяца'
            WHEN a.days_exposition <= 90 THEN 'В течение 1 квартала'
            when a.days_exposition <= 182 THEN 'В течение полугода'
            WHEN a.days_exposition >182 THEN 'Более полугода'
            ELSE 'Активные'
        END AS exposition_category
    FROM
        real_estate.advertisement a
), 
-- Выгружаю показатели и делю на две группы (СПБ и ЛО)
FlatStats AS (
    SELECT 
        tc.exposition_category,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.rooms) AS rooms,
        AVG( f.total_area) AS total_area,
        AVG(a.last_price / f.total_area) AS price_per_meter,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.floor) AS floor,
        PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY f.is_apartment) AS is_apartment,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS subject,
     	count(a.id) as object
    FROM 
        TimeCategories tc
    JOIN 
        real_estate.flats f ON tc.id = f.id
    JOIN 
        real_estate.advertisement a ON tc.id = a.id
    JOIN 
        real_estate.city c ON f.city_id = c.city_id
    JOIN 
        real_estate.type t ON f.type_id = t.type_id
    WHERE 
        t.type = 'город'
    GROUP BY 
        subject,
        tc.exposition_category
)
-- Итоговая выгрузка по показателям (скорость продажи, регион, ко-во комнат, метры, этажи и является ли аппартаментами)
SELECT 
    subject,
    fs.exposition_category,
    object,
    fs.rooms,
    ROUND(fs.total_area::numeric, 2) as total_area,
    ROUND(fs.price_per_meter::numeric, 2) as price_per_meter,
    fs.floor,
    fs.is_apartment
FROM
    FlatStats fs
ORDER BY
    subject,
    total_area;
SELECT * FROM retail_events_db.fact_events;

ALTER TABLE fact_events
RENAME COLUMN `quantity_sold(before_promo)` TO `qsb`,
RENAME COLUMN `quantity_sold(after_promo)` TO `qsa`;

/////1
SELECT dp.product_name, fe.promo_type, fe.base_price
FROM fact_events AS fe
JOIN dim_products AS dp
ON dp.product_code = fe.product_code
WHERE base_price > 500
AND promo_type = 'BOGOF'
ORDER BY base_price ASC;

/////2
SELECT city, count(store_id) AS store_count
FROM dim_stores
GROUP BY city
ORDER BY store_count DESC;

//////////3
WITH DiscountValues AS (
  SELECT
    campaign_id,
    CASE
      WHEN promo_type LIKE '%50%' THEN 0.50
      WHEN promo_type LIKE '%25%' THEN 0.25
      WHEN promo_type LIKE '%33%' THEN 0.33
      WHEN promo_type LIKE '%BOGO%' THEN 0.50 -- Assuming "BOGO" translates to 50% discount
      WHEN promo_type LIKE '%cashback%' THEN
      CAST(SUBSTRING_INDEX(promo_type, ' ', 1) AS DECIMAL(6, 2)) / fe.base_price -- Extract cashback amount using SUBSTRING_INDEX
      ELSE 0 -- Handle potential errors or unknown promo types
    END AS discount
  FROM fact_events AS fe
)

SELECT
  dc.campaign_name,
  CONCAT(ROUND(SUM(fe.qsb * fe.base_price) / 1000000,0), ' M') AS total_revenue_before_promotion,
  CONCAT(ROUND(SUM(fe.qsa * fe.base_price * (1 - dv.discount)) / 1000000,0), ' M') AS total_revenue_after_promotion
FROM fact_events AS fe
JOIN dim_campaigns AS dc ON fe.campaign_id = dc.campaign_id
LEFT JOIN DiscountValues AS dv ON fe.campaign_id = dv.campaign_id
GROUP BY dc.campaign_name
ORDER BY campaign_name;

///////4
WITH CampaignData AS (
  SELECT
    dp.category,
    fe.qsb AS quantity_before_promo,
    fe.qsa AS quantity_after_promo,
    (fe.qsa - fe.qsb) AS incremental_sold_quantity
  FROM fact_events AS fe
  JOIN dim_products AS dp ON fe.product_code = dp.product_code
  JOIN dim_campaigns AS dc ON fe.campaign_id = dc.campaign_id
  WHERE dc.campaign_name LIKE 'Diwali%'
)

SELECT
  cd.category,
  CONCAT(ROUND(AVG(cd.incremental_sold_quantity / cd.quantity_before_promo) * 100, 2), ' %') AS 'ISU%',
  RANK() OVER (ORDER BY AVG(cd.incremental_sold_quantity / cd.quantity_before_promo) DESC) AS rank_order
FROM CampaignData AS cd
GROUP BY cd.category
ORDER BY rank_order;

/////5
WITH CampaignData AS (
  SELECT
    dp.product_name,
    dp.category,
    fe.base_price,
    fe.promo_type,
    fe.qsb AS quantity_before_promo,
    fe.qsa AS quantity_after_promo,
    (fe.qsa * fe.base_price * (1 - CASE 
                                  WHEN fe.promo_type LIKE '%50%' THEN 0.50
                                  WHEN fe.promo_type LIKE '%25%' THEN 0.25
                                  WHEN fe.promo_type LIKE '%33%' THEN 0.33
                                  WHEN fe.promo_type LIKE '%BOGO%' THEN 0.50
                                  WHEN fe.promo_type LIKE '%cashback%' THEN 
                                  CAST(SUBSTRING_INDEX(fe.promo_type, ' ', 1) AS DECIMAL(6, 2)) / fe.base_price
                                  ELSE 0
                                END)) AS incremental_revenue
  FROM fact_events AS fe
  JOIN dim_products AS dp ON fe.product_code = dp.product_code
)

SELECT
  cd.product_name,
  cd.category,
  ROUND(AVG(cd.incremental_revenue / (cd.quantity_before_promo * cd.base_price)) * 100, 2) AS 'IR%'
FROM CampaignData AS cd
GROUP BY cd.product_name, cd.category
ORDER BY 'IR%' DESC
LIMIT 5;

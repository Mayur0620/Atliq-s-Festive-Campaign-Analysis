select * from fact_events;

select city, sum(base_price) from fact_events f
inner join dim_stores s
on s.store_id=f.store_id
GROUP BY city;

select campaign_name, sum(quantity_sold_before_promo) as Total_Quanities_Sold_before_promo, 
sum(quantity_sold_after_promo) as Total_Quanities_Sold_after_promo from fact_events f
inner join dim_campaigns C
on C.campaign_id = f.campaign_id
GROUP BY campaign_name;

select category, sum(quantity_sold_after_promo) as Total_Quanities_Sold_after_promo from fact_events f
inner join dim_products p
on p.product_code=f.product_code
group by category;

select * from dim_campaigns;
select * from dim_products;
select * from dim_stores;
select * from fact_events;


-- 1. List Products with base price greater than 500 and featured in 'BOGOF' promo type --
select distinct(product_name), base_price, promo_type from fact_events f
inner join dim_products p
on p.product_code = f.product_code
where base_price > 500 and promo_type = "BOGOF";

-- 2. List Number of Stores in each City --
select city, count(store_id) as store_counts from dim_stores
group by city
order by store_counts DESC; 

-- Adding A new Column: Total Quantities Sold After Promo --
ALTER TABLE fact_events
ADD COLUMN total_quantities_sold_after_promo INT;

UPDATE fact_events
SET total_quantities_sold_after_promo = CASE 
                                            WHEN promo_type = 'BOGOF' THEN quantity_sold_after_promo * 2 
                                            ELSE quantity_sold_after_promo 
                                         END;
                                         
-- Adding A new Column: Promotional Price --
ALTER TABLE fact_events
ADD COLUMN promotional_price INT;

UPDATE fact_events
SET promotional_price = CASE 
                            WHEN promo_type = '25% OFF' THEN base_price * 0.75
                            WHEN promo_type = '33% OFF' THEN base_price * 0.67
                            WHEN promo_type = '50% OFF' THEN base_price * 0.5
                            WHEN promo_type = 'BOGOF' THEN base_price * 0.5
                            WHEN promo_type = '500 Cashback' THEN base_price - 500
                            ELSE base_price
                        END;

-- Adding A new Column: Base Price group--
ALTER TABLE fact_events
ADD COLUMN base_price_group VARCHAR(20);

UPDATE fact_events
SET base_price_group = CASE 
                            WHEN base_price>=0 AND base_price<=500 THEN '0-500'
                            WHEN base_price>500 AND base_price<=1000 THEN '500-1000'
                            WHEN base_price>1000 AND base_price<=1500 THEN '1000-1500'
                            WHEN base_price>1500 AND base_price<=2000 THEN '1500-2000'
                            WHEN base_price>2000 AND base_price<=2500 THEN '2000-2500'
                            WHEN base_price>2500 AND base_price<=3000 THEN '2500-3000'
                            ELSE base_price
                        END;
                        
                        
-- Adding A new Column: Total Revenue Before Promo --
ALTER TABLE fact_events
ADD COLUMN total_revenue_before_promo INT;

UPDATE fact_events
SET total_revenue_before_promo = base_price * quantity_sold_before_promo;                        

-- Adding A new Column: Total Revenue After Promo --
ALTER TABLE fact_events
ADD COLUMN total_revenue_after_promo INT;

UPDATE fact_events
SET total_revenue_after_promo = promotional_price * total_quantities_sold_after_promo;

select * from fact_events;

-- 3. List Campaigns with their Total Revenue generated before and after campaigns -- 
SELECT c.campaign_name as Campaign, concat(round(sum(f.total_revenue_before_promo)/1000000,0), 'M') as Total_Revenue_before_Promo, 
concat(round(sum(f.total_revenue_after_promo)/1000000,0), 'M') as Total_Revenue_after_Promo FROM Fact_events f
INNER JOIN dim_campaigns C
on c.campaign_id=f.campaign_id
group by campaign_name;

-- 4. List product categories with their rank based on their Incremental Sold Units(ISU%) during Diwali Campaign --
with Diwali_ISU as (
	select c.campaign_name, p.category, round(((sum(total_quantities_sold_after_promo)-sum(quantity_sold_before_promo))/sum(quantity_sold_before_promo))*100,0) as ISU_percentage from fact_events f
	inner join dim_campaigns c
	on c.campaign_id=f.campaign_id
	inner join dim_products p
	on p.product_code=f.product_code
	where campaign_name="Diwali"
	group by p.category
)
select Rank() over (ORDER BY ISU_percentage DESC) as Rank_No, category, ISU_percentage
from Diwali_ISU 
order by Rank_No;

-- 5. List Top 5 products with their rank based on their Incremental Revenue Percentage across all campaigns --
with IR as (
	select c.campaign_name, p.product_name, round((sum(total_revenue_after_promo)-sum(total_revenue_before_promo))/sum(total_revenue_before_promo)*100,0) as IR_percentage from fact_events f
	inner join dim_campaigns c
	on c.campaign_id=f.campaign_id
	inner join dim_products p
	on p.product_code=f.product_code
	group by c.campaign_name, p.product_name
)
select Rank() over (ORDER BY IR_percentage DESC) as Rank_No, campaign_name, product_name, IR_percentage
from IR 
order by Rank_No
limit 5;



select * from dim_campaigns;
select * from dim_products;
select * from dim_stores;
select * from fact_events;


-- Research Questions -- 

-- 1. List Number of products available in each category
SELECT category, count(DISTINCT(product_name)) as Total_unique_products
from dim_products
group by Category;

-- 2. List Campaigns by Average revenue and Average quantity sold per Order
SELECT c.campaign_name, concat(round(AVG(total_revenue_after_promo) / 1000,0), 'K') AS Average_revenue_per_Order, 
round(AVG(total_quantities_sold_after_promo),0) AS Average_quantity_sold_per_order
FROM fact_events f
Inner Join dim_campaigns c
ON c.campaign_id=f.campaign_id
Group by c.campaign_name
ORDER BY Average_revenue_per_Order DESC;

-- 3. List Top 5 products by Average revenue and Average quantity sold per Order
SELECT p.product_name, round(avg(total_revenue_after_promo),0) AS Average_revenue_per_Order, 
round(AVG(total_quantities_sold_after_promo),0) AS Average_quantity_sold_per_order
FROM fact_events f
Inner Join dim_products p
ON p.product_code=f.product_code
Group by p.product_name
ORDER BY Average_revenue_per_Order DESC
LIMIT 5;

-- 4. List Top 5 products in each product category by Average revenue and Average quantity sold per Order

SELECT p.product_name, p.category, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE p.category = 'Grocery & Staples'
GROUP BY p.product_name, p.category
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, p.category, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order,
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE p.category = 'Home Care'
GROUP BY p.product_name, p.category
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, p.category, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order,
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE p.category = 'Personal Care'
GROUP BY p.product_name, p.category
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, p.category, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order,
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE p.category = 'Home Appliances'
GROUP BY p.product_name, p.category
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

-- 5. List Top 5 products in each base price group by Average revenue and Average quantity sold per Order

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '0-500'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '500-1000'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '1000-1500'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '1500-2000'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '2000-2500'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;

SELECT p.product_name, base_price_group, round(AVG(total_revenue_after_promo),0) AS Avg_revenue_per_order, 
round(AVG(total_quantities_sold_after_promo),0) AS Avg_quantity_sold_per_order FROM fact_events f
INNER JOIN dim_products p
ON p.product_code=f.product_code
WHERE base_price_group = '2500-3000'
GROUP BY p.product_name, base_price_group
ORDER BY Avg_revenue_per_order DESC
LIMIT 5;


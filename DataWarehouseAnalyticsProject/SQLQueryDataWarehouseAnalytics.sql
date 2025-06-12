
-- Change Over Time Analysis


SELECT 
YEAR(order_date) AS order_year, 
MONTH(order_date) AS order_month, 
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS totoal_customers,
SUM(quantity) AS total_quantity
FROM DataWarehouseAnalytics.gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date) ASC


SELECT 
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS totoal_customers,
SUM(quantity) AS total_quantity
FROM DataWarehouseAnalytics.gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date) ASC

-- Cumilative Analysis
-- Calculate the total sales per month and the running total of sales over time


SELECT *
FROM DataWarehouseAnalytics.gold.fact_sales


SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_sales,
SUM(SUM(sales_amount)) OVER (ORDER BY YEAR(order_date), MONTH(order_date)) AS culminative_sales,
AVG(AVG(price)) OVER (ORDER BY YEAR(order_date), MONTH(order_date)) AS moving_average_sales
FROM DataWarehouseAnalytics.gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date) ASC


-- With CTE

WITH sales_data AS (
	SELECT
	YEAR(order_date) AS order_year,
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS average_price
	FROM DataWarehouseAnalytics.gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY YEAR(order_date), MONTH(order_date)
)

SELECT 
sd.order_year, 
sd.order_month, 
sd.total_sales, 
SUM(sd.total_sales) OVER (ORDER BY sd.order_year, sd.order_month) AS culminative_sales,
AVG(sd.average_price) OVER (ORDER BY sd.order_year, sd.order_month) AS moving_average_price
FROM sales_data sd


-- Performance Analysis
-- Analyze yearly performance of products by comparing their sales to both the average sales performance of the product and the previous year's sales

WITH yearly_product_sales AS (
SELECT
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales 
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)

SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS average_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE 
	 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	 ELSE 'Avg'
END AS avg_change,
-- Year-over-year Analysis
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_diff,
CASE 
	 WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	 WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	 ELSE 'Unchanged'
END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year


-- Part-to-Whole Analysis
-- Which categories contribute the most to overall sales

SELECT
*
FROM gold.dim_products

SELECT
*
FROM gold.fact_sales

WITH sales_to_whole AS (
SELECT
category,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY category
)

SELECT 
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND((CAST (total_sales AS FLOAT) /SUM(total_sales) OVER ())*100, 2), '%') AS sales_portion
FROM sales_to_whole
ORDER BY sales_portion DESC


-- Data Segmentation
-- Segment products into cost ranges and count how many products fall into each segment


WITH cost_table AS (
SELECT
product_key,
product_name,
cost,
CASE 
	 WHEN cost < 100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END AS cost_range
FROM gold.dim_products
)

SELECT
cost_range,
COUNT(product_key) AS total_products
FROM cost_table
GROUP BY cost_range
ORDER BY total_products DESC


/*Group customers into three segments based on their spending behavior:
    - VIP: Customers with at least 12 months of history and spending more than €5,000.
    - Regular: Customers with at least 12 months of history but spending €5,000 or less.
    - New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

-- Segmentation

WITH customer_groups AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT 
customer_key,
total_spending,
life_span,
CASE 
	 WHEN life_span >= 12 AND total_spending > 5000 THEN 'VIP'
	 WHEN life_span >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment
FROM customer_groups


-- Total number


WITH customer_groups AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_sales,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
customer_segment,
COUNT(customer_key) AS total_customers
FROM (
	SELECT 
	customer_key,
	--total_spending,
	--life_span,
	CASE 
		 WHEN life_span >= 12 AND total_sales > 5000 THEN 'VIP'
		 WHEN life_span >= 12 AND total_sales <= 5000 THEN 'Regular'
		 ELSE 'New'
	END AS customer_segment
	FROM customer_groups
) t
GROUP BY customer_segment
ORDER BY total_customers DESC
--ORDER BY customer_key


/*
===============================================================================
Customer Report
===============================================================================

Purpose:
  - This report consolidates key customer metrics and behaviors

Highlights:
  1. Gathers essential fields such as names, ages, and transaction details.
  2. Segments customers into categories (VIP, Regular, New) and age groups.
  3. Aggregates customer-level metrics:
     - total orders
     - total sales
     - total quantity purchased
     - total products
     - lifespan (in months)
  4. Calculates valuable KPIs:
     - recency (months since last order)
     - average order value
     - average monthly spend
===============================================================================
*/

CREATE VIEW gold.report_customers AS
WITH base_query AS (

/*===============================================================================
  1) Base Query:Retrieve core columns from tables
===============================================================================*/

SELECT
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATEDIFF(year, c.birthdate, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL
)

, customer_aggregation AS (

/*===============================================================================
  2) Customer Aggregation: Summarize key metrics at the customer level
===============================================================================*/

SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span
FROM base_query
GROUP BY
customer_key,
customer_number,
customer_name,
age
)

/*===============================================================================
  3) Final Query: Bring everything together, including KPI's
===============================================================================*/


SELECT
customer_key,
customer_number,
customer_name,
age,
CASE 
	 WHEN age < 20 THEN 'Under 20'
	 WHEN age BETWEEN 20 AND 29 THEN '20-29'
	 WHEN age BETWEEN 30 AND 39 THEN '30-39'
	 WHEN age BETWEEN 40 AND 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE 
	 WHEN life_span >= 12 AND total_sales > 5000 THEN 'VIP'
	 WHEN life_span >= 12 AND total_sales <= 5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment,
last_order_date,
DATEDIFF(month, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_products,
life_span,
-- Compute average order value (AOV)
CASE 
	 WHEN total_orders = 0 THEN 0
	 ELSE total_sales/total_orders
END AS avg_order_value,
-- Compute average monthly spend
CASE 
	 WHEN life_span = 0 THEN total_sales
	 ELSE total_sales/life_span
END AS avg_monthly_spend
FROM customer_aggregation


/*
===============================================================================
Product Report
===============================================================================

Purpose:
  - This report consolidates key product metrics and behaviors.

Highlights:
  1. Gathers essential fields such as product name, category, subcategory, and cost.
  2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
  3. Aggregates product-level metrics:
     - total orders
	 - total sales
     - total quantity sold
     - total customers (unique)
     - lifespan (in months)
  4. Calculates valuable KPIs:
     - recency (months since last order)
     - average order revenue (AOR)
     - average monthly revenue
===============================================================================
*/

CREATE VIEW gold.report_products AS

WITH base_query AS (

/*===============================================================================
  1) Base Query:Retrieve core columns from tables
===============================================================================*/

SELECT 
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost,
f.order_number,
f.customer_key,
f.order_date,
f.sales_amount,
f.quantity
FROM gold.dim_products p
LEFT JOIN gold.fact_sales f
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
)

, product_aggregation AS (

/*===============================================================================
  2) Product Aggregation: Summarize key metrics at the product level
===============================================================================*/

SELECT
product_key,
product_name,
category,
subcategory,
cost,
COUNT(DISTINCT order_number) AS total_orders,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span,
DATEDIFF(month, MAX(order_date), GETDATE()) AS recency
FROM base_query
GROUP BY
product_key,
product_name,
category,
subcategory,
cost
) 

/*===============================================================================
  3) Final Query: Bring everything together, including KPI's
===============================================================================*/


SELECT
product_name,
category,
subcategory,
cost,
total_orders,
total_sales,
total_quantity,
total_customers,
life_span,
recency,
CASE WHEN total_sales < 20000 THEN 'Low_performer'
	 WHEN total_sales BETWEEN 20000 AND 50000 THEN 'Mid_range'
	 ELSE 'High_Performer'
END AS product_segment,
-- Calculate average order revenue (AOR)
CASE WHEN total_orders = 0 THEN 0
	 ELSE total_sales/total_orders
END AS avg_order_revenue,
CASE WHEN life_span = 0 THEN total_sales
	 ELSE total_sales/life_span
END AS avg_monthly_revenue
FROM product_aggregation
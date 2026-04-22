CREATE DATABASE ecommerce_project;
USE ecommerce_project;

-- Orders Table
CREATE TABLE cleaned_orders (
    order_id VARCHAR(255),
    customer_id VARCHAR(255),
    order_status VARCHAR(50),
    order_purchase_timestamp VARCHAR(50),
    order_approved_at VARCHAR(50),
    order_delivered_carrier_date VARCHAR(50),
    order_delivered_customer_date VARCHAR(50),
    order_estimated_delivery_date VARCHAR(50)
);

-- 2. Bulk Import the data (pointing to your unzipped CSV)
SET GLOBAL local_infile = 1;

SHOW VARIABLES LIKE 'local_infile';

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/Anusha/cleaned_orders.csv'
INTO TABLE cleaned_orders  
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 3. Clean up the "empty" spaces that cause errors
SET SQL_SAFE_UPDATES = 0;
UPDATE cleaned_orders SET 
    order_approved_at = NULLIF(TRIM(order_approved_at), ''),
    order_delivered_carrier_date = NULLIF(TRIM(order_delivered_carrier_date), ''),
    order_delivered_customer_date = NULLIF(TRIM(order_delivered_customer_date), '');

UPDATE cleaned_orders 
SET 
    order_purchase_timestamp = STR_TO_DATE(order_purchase_timestamp, '%d-%m-%Y %H:%i'),
    order_approved_at = STR_TO_DATE(order_approved_at, '%d-%m-%Y %H:%i'),
    order_delivered_carrier_date = STR_TO_DATE(order_delivered_carrier_date, '%d-%m-%Y %H:%i'),
    order_delivered_customer_date = STR_TO_DATE(order_delivered_customer_date, '%d-%m-%Y %H:%i'),
    order_estimated_delivery_date = STR_TO_DATE(order_estimated_delivery_date, '%d-%m-%Y %H:%i');

-- 4. Final Step: Convert to proper DATETIME types for analysis
ALTER TABLE cleaned_orders 
MODIFY COLUMN order_purchase_timestamp DATETIME,
MODIFY COLUMN order_approved_at DATETIME,
MODIFY COLUMN order_delivered_carrier_date DATETIME,
MODIFY COLUMN order_delivered_customer_date DATETIME,
MODIFY COLUMN order_estimated_delivery_date DATETIME;

SET SQL_SAFE_UPDATES = 1;

-- 5. Show me the final count to confirm
SELECT COUNT(*) AS total_rows FROM cleaned_orders;

DESCRIBE cleaned_orders;

SELECT COUNT(*) FROM cleaned_orders;

-- Geolocation Table
CREATE TABLE cleaned_geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DOUBLE,
    geolocation_lng DOUBLE,
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE "C:/Users/user/Downloads/Anusha/cleaned_geolocation.csv"
INTO TABLE cleaned_geolocation
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Products Table 
CREATE TABLE cleaned_products (
    product_id VARCHAR(255),
    product_category VARCHAR(255),
    product_name_length VARCHAR(50),
    product_description_length VARCHAR(50),
    product_photos_qty VARCHAR(50),
    product_weight_g VARCHAR(50),
    product_length_cm VARCHAR(50),
    product_height_cm VARCHAR(50),
    product_width_cm VARCHAR(50)
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE "C:/Users/user/Downloads/Anusha/cleaned_products.csv"
INTO TABLE cleaned_products
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

SELECT COUNT(*) FROM cleaned_products;

USE ecommerce_project;

-- Turn off Safe Updates to allow the cleanup
SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_products 
SET 
    product_name_length = NULLIF(TRIM(product_name_length), ''),
    product_description_length = NULLIF(TRIM(product_description_length), ''),
    product_photos_qty = NULLIF(TRIM(product_photos_qty), ''),
    product_weight_g = NULLIF(TRIM(product_weight_g), ''),
    product_length_cm = NULLIF(TRIM(product_length_cm), ''),
    product_height_cm = NULLIF(TRIM(product_height_cm), ''),
    product_width_cm = NULLIF(TRIM(product_width_cm), '');

SET SQL_SAFE_UPDATES = 1;

ALTER TABLE cleaned_products 
MODIFY COLUMN product_name_length INT,
MODIFY COLUMN product_description_length INT,
MODIFY COLUMN product_photos_qty INT,
MODIFY COLUMN product_weight_g INT,
MODIFY COLUMN product_length_cm INT,
MODIFY COLUMN product_height_cm INT,
MODIFY COLUMN product_width_cm INT;

DESCRIBE cleaned_products;

SELECT COUNT(*) FROM cleaned_products;

ALTER TABLE cleaned_order_items 
MODIFY COLUMN price DECIMAL(10,2);

SELECT * FROM cleaned_order_items;

-- 1) BASIC PROBLEMS :
-- OBJECTIVE : Extract Fundamental insights from the dataset.....
-- Q1 : List all unique cities where customers are located.....
SELECT DISTINCT customer_city 
FROM cleaned_customers;

-- Q2 : Count the number of orders placed in 2017.....
SELECT COUNT(order_id) 
FROM cleaned_orders 
WHERE YEAR(order_purchase_timestamp) = 2017;

-- Q3 : Find the total sales per category.....
SELECT product_category, SUM(oi.price) AS total_sales
FROM cleaned_order_items oi
JOIN cleaned_products p ON oi.product_id = p.product_id
GROUP BY product_category
ORDER BY total_sales DESC;

-- Q4 : Calculate the percentage of orders that were paid in installments.....
SELECT 
     (COUNT(CASE WHEN Payment_installments > 1 THEN 1 END)/COUNT(*)) * 100 
				AS installment_percentage
FROM cleaned_payments;

-- Q5 : Count the number of customers from each state.....
SELECT customer_state, COUNT(customer_id) AS customer_count
FROM cleaned_customers
GROUP BY customer_state
ORDER BY customer_count DESC;

-- 2) INTERMEDIATE PROBLEMS :
-- Objective : Dive deeper into sales and order trends......
-- Q1 : Calculate the numbers of orders per month in 2018.....
SELECT 
      YEAR(order_purchase_timestamp) AS YEAR,
      MONTH(order_purchase_timestamp) AS month, 
      COUNT(order_id) AS order_count
FROM cleaned_orders
WHERE YEAR(order_purchase_timestamp) = 2018
GROUP BY Year, month
ORDER BY Year, month;

-- Q2 : Find the average number of products per order, grouped by customer city.....
WITH OrderProductCount AS (
    SELECT o.order_id, o.customer_id,
        COUNT(oi.product_id) AS Product_Count
    FROM cleaned_orders o
    JOIN cleaned_order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT c.customer_city,
    AVG(opc.Product_Count) AS avg_products_per_order
FROM OrderProductCount opc
JOIN cleaned_customers c 
    ON opc.customer_id = c.customer_id
GROUP BY c.customer_city
ORDER BY avg_products_per_order DESC;

-- Q3. Calculate the percentage of total revenue contributed by each product category.....
SELECT p.`product_category`, (SUM(oi.price) / (SELECT SUM(price) 
     FROM cleaned_order_items)) * 100 AS revenue_pct
FROM cleaned_order_items oi
JOIN cleaned_products p ON oi.product_id = p.product_id
GROUP BY p.`product_category`
ORDER BY revenue_pct DESC;

-- Q4 : Identify the correlation between product price and the number of times a product has been purchased.....
SELECT price, 
       COUNT(product_id) AS Times_Purchased
FROM cleaned_order_items
GROUP BY price
ORDER BY price;
 
-- Q5 : Calculate the total revenue generated by each seller, and rank them by revenue.....
SELECT seller_id, SUM(price) AS revenue,
       RANK() OVER (ORDER BY SUM(price) DESC) AS seller_rank
FROM cleaned_order_items
GROUP BY seller_id
ORDER BY seller_rank;


-- 3) ADVANCED PROBLEMS : 
-- Objective : Generate strategic and customer-centric insights......
-- Q1 : Calculate the moving average of order values for each customer over their order history.....
SELECT customer_id, order_purchase_timestamp, payment_value,
       AVG(payment_value) OVER (PARTITION BY customer_id 
               ORDER BY order_purchase_timestamp ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) 
				AS moving_avg
FROM cleaned_orders o
JOIN cleaned_payments p ON o.order_id = p.order_id;

-- Q2 : Calculate the cumulative sales per month for each year.....
SELECT YEAR(order_purchase_timestamp) AS year, MONTH(order_purchase_timestamp) AS month,
       SUM(SUM(payment_value)) OVER (PARTITION BY YEAR(order_purchase_timestamp) 
             ORDER BY MONTH(order_purchase_timestamp)) AS cumulative_sales
FROM cleaned_orders o
JOIN cleaned_payments p ON o.order_id = p.order_id
GROUP BY year, month;

-- Q3 : Calculate the year-over-year growth rate of total sales.....
WITH yearly_sales AS (
	 SELECT YEAR(o.order_purchase_timestamp) AS year, SUM(p.payment_value) AS revenue
	 FROM cleaned_orders o
	 JOIN cleaned_payments p ON o.order_id = p.order_id
	 GROUP BY year
)
SELECT 
	  year, revenue,
	  LAG(revenue) OVER (ORDER BY year) AS prev_year_revenue,
	  ((revenue - LAG(revenue) OVER (ORDER BY year)) / LAG(revenue) OVER (ORDER BY year)) * 100 
        AS yoy_growth
FROM yearly_sales;

-- Q4 : Calculate the retention rate of customers, defined as the percentage of customers who make another purchase within 6 months of their first purchase.....
WITH first_purchase AS (
    SELECT customer_unique_id, 
           MIN(order_purchase_timestamp) AS first_order
    FROM cleaned_orders o 
    JOIN cleaned_customers c ON o.customer_id = c.customer_id
    GROUP BY customer_unique_id
),
retention AS (
    SELECT f.customer_unique_id,
           COUNT(o.order_id) AS second_purchase
    FROM first_purchase f
    LEFT JOIN cleaned_customers c ON f.customer_unique_id = c.customer_unique_id
    LEFT JOIN cleaned_orders o ON c.customer_id = o.customer_id
        AND o.order_purchase_timestamp > f.first_order
        AND o.order_purchase_timestamp <= DATE_ADD(f.first_order, INTERVAL 6 MONTH)
    GROUP BY f.customer_unique_id 
)
SELECT 
    (COUNT(CASE WHEN second_purchase > 0 THEN 1 END) / COUNT(*)) * 100 AS retention_rate
FROM retention;

-- Q5 : Identify the top 3 customers who spent the most money in each year.....
SELECT year, customer_id, total_spent, spender_rank
FROM (
    SELECT YEAR(o.order_purchase_timestamp) AS year, c.customer_id, SUM(p.payment_value) AS total_spent,
           RANK() OVER (PARTITION BY YEAR(o.order_purchase_timestamp) ORDER BY SUM(p.payment_value) DESC) 
           AS spender_rank
    FROM cleaned_orders o
    JOIN cleaned_payments p ON o.order_id = p.order_id
    JOIN cleaned_customers c ON o.customer_id = c.customer_id
    GROUP BY year, c.customer_id
) t
WHERE spender_rank <= 3
ORDER BY Year, spender_rank;
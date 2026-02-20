CREATE SCHEMA ecommerce_db; 
use ecommerce_db;

-- 1. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state CHAR(2)
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/customers.csv'
INTO TABLE customers 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 2. SELLERS
CREATE TABLE IF NOT EXISTS sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/sellers.csv' 
INTO TABLE sellers 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 3. ORDER_ITEMS
CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/order_items.csv' 
INTO TABLE order_items 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 4. PAYMENTS
CREATE TABLE IF NOT EXISTS payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/payments.csv' 
INTO TABLE payments 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 5. ORDERS (Import as TEXT for dates to avoid format errors)
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at VARCHAR(50),
    order_delivered_carrier_date VARCHAR(50),
    order_delivered_customer_date VARCHAR(50),
    order_estimated_delivery_date DATETIME
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/orders.csv' 
INTO TABLE orders 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- 6. PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/products.csv' 
INTO TABLE products 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n' 
IGNORE 1 ROWS;

-- Widen columns to prevent 'Data Truncated' warnings
ALTER TABLE customers MODIFY customer_city VARCHAR(255), MODIFY customer_state VARCHAR(50);
ALTER TABLE sellers MODIFY seller_city VARCHAR(255), MODIFY seller_state VARCHAR(50);
ALTER TABLE products MODIFY product_category VARCHAR(255);
ALTER TABLE orders MODIFY order_status VARCHAR(100);
ALTER TABLE geolocation MODIFY geolocation_city VARCHAR(255), MODIFY geolocation_state VARCHAR(50);

-- 7. GEOLOCATION
CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix INT,
    geolocation_lat DECIMAL(20,15),
    geolocation_lng DECIMAL(20,15),
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2)
);

LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/SQL/geolocation.csv' 
INTO TABLE geolocation 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' LINES 
TERMINATED BY '\n' 
IGNORE 1 ROWS;

SELECT * FROM customers LIMIT 5;

-- 1) BASIC PROBLEMS : 
-- Objective : Extract fundamental insights from the dataset......
-- Q1 : List all unique cities where customers are located.....
SELECT DISTINCT customer_city 
FROM customers;

-- Q2 : Count the number of orders placed in 2017.....
SELECT COUNT(order_id) AS total_orders_2017 
FROM orders 
WHERE order_purchase_timestamp BETWEEN '2017-01-01 00:00:00' AND '2017-12-31 23:59:59';

-- Q3 : Find the total sales per category.....
SELECT p.product_category, sum(oi.price) AS total_sales
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category
ORDER BY total_sales DESC;

-- Q4 : Calculate the percentage of orders that were paid in installments.....
SELECT 
    (COUNT(CASE WHEN payment_installments > 1 THEN 1 END) / COUNT(*)) * 100 AS installment_percentage
FROM payments;

-- Q5 : Count the number of customers from each state.....
SELECT customer_state, COUNT(customer_id) AS customer_count
FROM customers
GROUP BY customer_state
ORDER BY customer_count DESC;



-- 2) INTERMEDIATE PROBLEMS : 
-- Objective : Dive deeper into sales and order trends......
-- Q1 : Calculate the numbers of oredrs per month in 2018.....
SELECT MONTHNAME(order_purchase_timestamp) AS month, COUNT(order_id) AS order_count
FROM orders
WHERE YEAR(order_purchase_timestamp) = 2018
GROUP BY month
ORDER BY field(month, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');

-- Q2 : Find the average number of products per order, grouped by customer city.....
WITH count_per_order AS (
    SELECT orders.customer_id, order_items.order_id, count(order_items.order_item_id) AS item_count
    FROM orders
    JOIN order_items ON orders.order_id = order_items.order_id
    GROUP BY orders.customer_id, order_items.order_id
)
SELECT c.customer_city, ROUND(AVG(cp.item_count), 2) AS avg_items_per_order
FROM customers c
JOIN count_per_order cp ON c.customer_id = cp.customer_id
GROUP BY c.customer_city;

-- Q3 : Calculate the percentage of total revenue contributed by each product category.....
SELECT p.product_category, 
       ROUND((SUM(oi.price) / (SELECT SUM(price) FROM order_items) * 100), 2) AS sales_percentage
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_category
ORDER BY sales_percentage DESC;

-- Q4 : Identify the correlation between product price and the number of times a product has been purchased.....
-- Solution : Answer for this question is in google colab.....

-- Q5 : Calculate the total revenue generated by each seller, and rank them by revenue.....
SELECT seller_id, 
       SUM(price) AS revenue,
       RANK() OVER (ORDER BY SUM(price) DESC) AS seller_rank
FROM order_items
GROUP BY seller_id;



-- 3) ADVANCED PROBLEMS : 
-- Objective : Generate strategic and customer-centric insights......
-- Q1 : Calculate the moving average of order values for each customer over their order history.....
SELECT 
    customer_id, 
    order_purchase_timestamp, 
    payment_value,
    AVG(payment_value) OVER (
        PARTITION BY customer_id 
        ORDER BY order_purchase_timestamp 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg
FROM (
    SELECT o.customer_id, o.order_purchase_timestamp, p.payment_value
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
) AS subquery;

-- Q2 : Calculate the cumulative sales per month for each year.....
SELECT 
    year, month, monthly_sales,
    SUM(monthly_sales) OVER (PARTITION BY year ORDER BY month) AS cumulative_sales
FROM (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS year,
        MONTH(o.order_purchase_timestamp) AS month,
        SUM(p.payment_value) AS monthly_sales
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY year, month
) AS t;

-- Q3 : Calculate the year-over-year growth rate of total sales.....
WITH yearly_sales AS (
    SELECT YEAR(o.order_purchase_timestamp) AS year, SUM(p.payment_value) AS revenue
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY year
)
SELECT 
    year, revenue,
    LAG(revenue) OVER (ORDER BY year) AS prev_year_revenue,
    ((revenue - LAG(revenue) OVER (ORDER BY year)) / LAG(revenue) OVER (ORDER BY year)) * 100 AS yoy_growth
FROM yearly_sales;

-- Q4 : Calculate the retention rate of customers, defined as the percentage of customers who make another purchase within 6 months of their first purchase.....
WITH first_purchase AS (
    SELECT customer_unique_id, MIN(order_purchase_timestamp) AS first_order
    FROM orders o JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY customer_unique_id
),
retention AS (
    SELECT f.customer_unique_id, 
           COUNT(o.order_id) AS second_purchase
    FROM first_purchase f
    LEFT JOIN customers c ON f.customer_unique_id = c.customer_unique_id
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp > f.first_order 
      AND o.order_purchase_timestamp <= DATE_ADD(f.first_order, INTERVAL 6 MONTH)
    GROUP BY f.customer_unique_id
)
SELECT (COUNT(CASE WHEN second_purchase > 0 THEN 1 END) / COUNT(*)) * 100 AS retention_rate
FROM retention;

-- Q5 : Identify the top 3 customers who spent the most money in each year.....
SELECT year, customer_unique_id, total_spent, spender_rank
FROM (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS year,
        c.customer_unique_id,
        SUM(p.payment_value) AS total_spent,
        DENSE_RANK() OVER (PARTITION BY YEAR(o.order_purchase_timestamp) ORDER BY SUM(p.payment_value) DESC) AS spender_rank
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY year, c.customer_unique_id
) AS ranked_table
WHERE spender_rank <= 3;
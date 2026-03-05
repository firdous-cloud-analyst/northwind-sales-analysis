CREATE VIEW sales_fact AS
(SELECT o.id AS order_id,o.order_date,c.id AS customer_id,c.company,
CONCAT(e.first_name,' ',e.last_name)as salesperson, p.id AS product_id,
p.product_name,od.quantity,od.unit_price,od.discount,
(od.quantity * od.unit_price) *(1-od.discount) AS revenue
FROM orders o
JOIN order_details od
ON o.id=od.id
JOIN customers c
ON o.customer_id = c.id
JOIN employees e
ON o.employee_id =e.id
JOIN products p
ON od.product_id= p.id
);

SELECT*
FROM sales_fact;
-------------------------------------------------------------
-- ----------------------Total Revenue-----------------------
-------------------------------------------------------------
SELECT SUM(revenue) AS Total_revenue
FROM sales_fact;
-------------------------------------------------------------
-- ----------------------Total Orders-----------------------
------------------------------------------------------------
SELECT COUNT(DISTINCT order_id)AS Total_order
FROM sales_fact;
------------------------------------------------------------
-- --------------------Average Order Value------------------
------------------------------------------------------------
SELECT SUM(revenue)/COUNT(DISTINCT order_id) AS aov_order_value
FROM sales_fact;
------------------------------------------------------------
-- ------------------Revenue by Salesperson-----------------
------------------------------------------------------------
SELECT  SUM(revenue),salesperson
FROM sales_fact
GROUP BY salesperson;
------------------------------------------------------------
-- -----------------Top 5 Customers by Revenue--------------
------------------------------------------------------------
SELECT  SUM(revenue),customer_id
FROM sales_fact
GROUP BY customer_id
ORDER BY SUM(revenue)DESC
LIMIT 5;
------------------------------------------------------------
-- ----------------------Monthly Revenue--------------------
------------------------------------------------------------
SELECT 
	DATE_FORMAT(order_date,'%Y-%m')as  month,
	SUM(revenue) AS monthly_revenue
FROM  sales_fact
GROUP BY DATE_FORMAT(order_date,'%Y-%m') 
ORDER BY month;
-- --------------Monthly Growth %-------------
WITH Monthly_growth  AS
(SELECT 
	DATE_FORMAT(order_date,'%Y-%m')as  month,
	SUM(revenue) AS current_month_revenue
FROM  sales_fact
GROUP BY DATE_FORMAT(order_date,'%Y-%m') 
ORDER BY month)
SELECT
	month,current_month_revenue,
	LAG(current_month_revenue) OVER(ORDER BY month) previous_month,
    ROUND((current_month_revenue - LAG(current_month_revenue) OVER(ORDER BY month)) 
    / LAG(current_month_revenue) OVER(ORDER BY month) *100 ,2)as Grouth_Persntage
FROM Monthly_growth;
------------------------------------------------------------------
-- -----------------------Repeat Customer Rate--------------------
------------------------------------------------------------------
WITH CUSTOMER_ORDER AS 
(SELECT 
	customer_id,
	COUNT(DISTINCT (order_id)) Total_order
FROM sales_fact
GROUP BY customer_id)
SELECT 
	ROUND(SUM(CASE WHEN Total_order > 1 THEN 1 ELSE 0 END )
	/COUNT(*)*100,2) AS repeat_customer_rate_percentage
FROM CUSTOMER_ORDER;
------------------------------------------------------------
  -- -------------Customer Retention by Month---------------
------------------------------------------------------------
WITH customer_monthly AS
(SELECT 
    DISTINCT DATE_FORMAT(order_date,'%Y-%m')as  month_start,
    customer_id
    FROM sales_fact
    ),
monthly_count AS
    (SELECT
		month_start
		,COUNT(DISTINCT customer_id) Total_customer
    From customer_monthly
    GROUP BY month_start
    )
    SELECT
		mc.month_start,
        COUNT(DISTINCT cm.customer_id) retained_customer,
        ROUND(COUNT(DISTINCT cm.customer_id)/
        LAG(mc.Total_customer)OVER(ORDER BY mc. month_start)*100 ,2) retention_rate_percent
	FROM customer_monthly cm
    join customer_monthly pm
		ON cm.customer_id = pm.customer_id
		AND cm.month_start = DATE_FORMAT(
        DATE_ADD(STR_TO_DATE(pm.month_start,'%Y-%m'), INTERVAL 1 MONTH),
        '%Y-%m')
	JOIN monthly_count mc
		ON cm.month_start= mc.month_start
		GROUP BY mc.month_start
        ORDER BY mc.month_start;
---------------------------------------------------------------------
-- ----------------------COHORT ANALYSIS-----------------------------
---------------------------------------------------------------------
SELECT 
	customer_id,
	MIN(DATE_FORMAT(order_date,'%Y-%m')) AS cohort_month
FROM sales_fact
GROUP BY customer_id;

SELECT 
	DISTINCT customer_id,
	DATE_FORMAT(order_date,'%Y-%m') AS order_month
FROM sales_fact;

with first_purches as
	(SELECT 
		customer_id,
		MIN(DATE_FORMAT(order_date,'%Y-%m')) AS cohort_month
	FROM sales_fact
	GROUP BY customer_id),
custmer_activity as 
	(SELECT DISTINCT
		customer_id,
		DATE_FORMAT(order_date,'%Y-%m') AS order_month
    FROM sales_fact)
SELECT
	fp.cohort_month,
    TIMESTAMPDIFF(MONTH,
        STR_TO_DATE(CONCAT(fp.cohort_month,'-01'),'%Y-%m-%d'),
        STR_TO_DATE(CONCAT(ca.order_month,'-01'),'%Y-%m-%d')
    ) AS month_number,
    COUNT(DISTINCT ca.customer_id ) AS customers
FROM first_purches fp
JOIN custmer_activity ca
	ON fp.customer_id=ca.customer_id
GROUP BY  fp.cohort_month, month_number
ORDER BY fp.cohort_month, month_number;  
----------------------------------------------------------------------
-- ---------------cohort_retention_Persentage-------------------------
----------------------------------------------------------------------
with first_purches as
	(SELECT 
		customer_id,
		MIN(DATE_FORMAT(order_date,'%Y-%m')) AS cohort_month
	FROM sales_fact
	GROUP BY customer_id),
custmer_activity as 
	(SELECT DISTINCT
		customer_id,
		DATE_FORMAT(order_date,'%Y-%m') AS order_month
    FROM sales_fact),
cohort_data as 
	(SELECT
	fp.cohort_month,
    TIMESTAMPDIFF(MONTH,
        STR_TO_DATE(CONCAT(fp.cohort_month,'-01'),'%Y-%m-%d'),
        STR_TO_DATE(CONCAT(ca.order_month,'-01'),'%Y-%m-%d')
    ) AS month_number,
    COUNT(DISTINCT ca.customer_id ) AS customers
FROM first_purches fp
JOIN custmer_activity ca
	ON fp.customer_id=ca.customer_id
GROUP BY  fp.cohort_month, month_number
) 
SELECT
	cd.cohort_month,
    cd.month_number,
    cd.customers,
    ROUND(
        cd.customers / base.base_customers * 100,
        2
    ) AS retention_percentage
FROM cohort_data cd
JOIN ( SELECT 
        cohort_month,
        customers AS base_customers
    FROM cohort_data
    WHERE month_number = 0
    )base
ON cd.cohort_month = base.cohort_month
ORDER BY cd.cohort_month, cd.month_number;
---------------------------------------------------------------
-- -----------View Table of cohort retantion-------------------
---------------------------------------------------------------
CREATE VIEW cohort_retantion as(
with first_purches as
	(SELECT 
		customer_id,
		MIN(DATE_FORMAT(order_date,'%Y-%m')) AS cohort_month
	FROM sales_fact
	GROUP BY customer_id),
custmer_activity as 
	(SELECT DISTINCT
		customer_id,
		DATE_FORMAT(order_date,'%Y-%m') AS order_month
    FROM sales_fact),
cohort_data as 
	(SELECT
	fp.cohort_month,
    TIMESTAMPDIFF(MONTH,
        STR_TO_DATE(CONCAT(fp.cohort_month,'-01'),'%Y-%m-%d'),
        STR_TO_DATE(CONCAT(ca.order_month,'-01'),'%Y-%m-%d')
    ) AS month_number,
    COUNT(DISTINCT ca.customer_id ) AS customers
FROM first_purches fp
JOIN custmer_activity ca
	ON fp.customer_id=ca.customer_id
GROUP BY  fp.cohort_month, month_number
) 
SELECT
	cd.cohort_month,
    cd.month_number,
    cd.customers,
    ROUND(
        cd.customers / base.base_customers * 100,
        2
    ) AS retention_percentage
FROM cohort_data cd
JOIN ( SELECT 
        cohort_month,
        customers AS base_customers
    FROM cohort_data
    WHERE month_number = 0
    )base
ON cd.cohort_month = base.cohort_month
);

select * from cohort_retantion;
 

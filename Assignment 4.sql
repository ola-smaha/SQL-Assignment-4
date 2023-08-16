-- Calculate the average rental duration and total revenue for each customer,
-- along with their top 3 most rented film categories.
SELECT
	cu1.customer_id,
	AVG(r1.return_date - r1.rental_date) AS avg_rental_duration,
	SUM(p1.amount) AS total_revenue,
	c1.category_id,
	c1.name
FROM public.customer as cu1
INNER JOIN public.payment as p1
	ON 	p1.customer_id = cu1.customer_id
INNER JOIN public.rental as r1
	ON r1.rental_id = p1.rental_id
INNER JOIN public.inventory AS i1
	ON i1.inventory_id = r1.inventory_id
INNER JOIN public.film AS f1
	ON f1.film_id = i1.film_id
INNER JOIN public.film_category AS fc1
	ON fc1.film_id = f1.film_id
INNER JOIN public.category as c1
	ON c1.category_id = fc1.category_id
WHERE c1.category_id IN (
    SELECT
        fc2.category_id
    FROM
        public.customer AS cu2
    INNER JOIN public.payment AS p2
        ON p2.customer_id = cu2.customer_id
    INNER JOIN public.rental AS r2
        ON r2.rental_id = p2.rental_id
    INNER JOIN public.inventory AS i2
        ON i2.inventory_id = r2.inventory_id
    INNER JOIN public.film AS f2
        ON f2.film_id = i2.film_id
    INNER JOIN public.film_category AS fc2
        ON fc2.film_id = f2.film_id
    WHERE cu2.customer_id = cu1.customer_id
    GROUP BY fc2.category_id
    ORDER BY COUNT(fc2.category_id) DESC
    LIMIT 3
)
GROUP BY
	cu1.customer_id,
	c1.category_id,
	c1.name
ORDER BY
	cu1.customer_id


-- Identify customers who have never rented films but have made payments.
SELECT
	p.customer_id
FROM
	public.payment AS p
LEFT OUTER JOIN public.rental AS r
	ON r.rental_id = p.rental_id
WHERE
	p.customer_id NOT IN
	(
		SELECT r2.customer_id
		FROM public.rental as r2
	)


-- Find the correlation between customer rental frequency and the average rating of the rented films.
SELECT
	cu.customer_id,
	COUNT(r.rental_id) AS rent_frequency,
	f.rating
FROM public.customer AS cu
INNER JOIN public.rental AS r
	ON r.customer_id = cu.customer_id
INNER JOIN public.inventory AS i
	ON i.inventory_id = r.inventory_id
INNER JOIN public.film AS f
	ON f.film_id = i.film_id
GROUP BY cu.customer_id,f.rating
ORDER BY COUNT(r.rental_id) DESC
-- There doesn't seem to be a strong correlation between the customer rental frequency and the rating.
-- The level of parental guidance needed doesn't necessarily increase with the increase of rental frequency.


-- Determine the average number of films rented per customer, broken down by city.
WITH CTE_RENTED_IN_CITY AS
(
	SELECT
		cu.customer_id,
		cit.city,
		COUNT(f.film_id) AS total_rentals
	FROM
		public.film AS f
	INNER JOIN public.inventory AS i
		ON i.film_id = f.film_id
	INNER JOIN public.rental AS r
		ON i.inventory_id = r.inventory_id
	INNER JOIN public.customer AS cu
		ON r.customer_id = cu.customer_id
	INNER JOIN public.store AS s
		ON s.store_id = cu.store_id
	INNER JOIN public.address AS a
		ON a.address_id = s.address_id
	INNER JOIN public.city AS cit
		ON a.city_id = cit.city_id
	GROUP BY 
		cu.customer_id,
		cit.city
	ORDER BY cu.customer_id
)
SELECT 
	CTE_RENTED_IN_CITY.customer_id,
	CTE_RENTED_IN_CITY.city,
	ROUND(AVG(CTE_RENTED_IN_CITY.total_rentals),1) AS avg_rentals
FROM CTE_RENTED_IN_CITY
GROUP BY 	
	CTE_RENTED_IN_CITY.customer_id,
	CTE_RENTED_IN_CITY.city


-- Identify films that have been rented more than the average number of times and are currently not in inventory.
DROP TABLE IF EXISTS temp_total_rentals;
CREATE TEMPORARY TABLE  temp_total_rentals AS
(
	SELECT
		f.film_id,
		COUNT(f.film_id) AS total_rentals
	FROM
		public.film AS f
	LEFT JOIN public.inventory AS i
		ON i.film_id = f.film_id
	INNER JOIN public.rental AS r
		ON i.inventory_id = r.inventory_id
	GROUP BY f.film_id
);

CREATE INDEX idx_temp_total_rentals ON temp_total_rentals(film_id);

WITH CTE_avg_rentals AS
(
	SELECT ROUND(AVG(temp_total_rentals.total_rentals),2) AS avg_rentals
	FROM temp_total_rentals
)

SELECT *
FROM temp_total_rentals, CTE_avg_rentals
WHERE temp_total_rentals.total_rentals > CTE_avg_rentals.avg_rentals


-- Calculate the replacement cost of lost films for each store, considering the rental history.
SELECT
    s.store_id,
    COUNT(f.film_id) AS lost_film_count,
    SUM(f.replacement_cost) AS total_rep_cost
FROM
    public.store AS s
INNER JOIN public.staff AS st
	ON s.store_id = st.store_id
INNER JOIN public.rental AS r
	ON st.staff_id = r.staff_id
INNER JOIN public.inventory AS i
	ON r.inventory_id = i.inventory_id
INNER JOIN public.film AS f
	ON i.film_id = f.film_id
WHERE
 	r.return_date IS NULL 
	AND r.rental_date + (f.rental_duration * INTERVAL '1 day') < CURRENT_TIMESTAMP
GROUP BY
    s.store_id
-- NOTE: rental_date is of type timestamp, rental_duration is an integer.
--We can't add an integer to a timestamp, so we multiply by an interval of 1 day by using INTERVAL '...',
--assuming that the rental duration is in days,
--and finally we compare the new timestamp with our current timestamp.



-- Create a report that shows the top 5 most rented films in each category,
-- along with their corresponding rental counts and revenue.
SELECT
	fc1.category_id,
	f1.film_id,
	f1.title,
	SUM(p1.amount) AS total_revenue,
	COUNT(r1.rental_id) AS total_rentals
FROM public.payment AS p1
INNER JOIN public.rental AS r1
	ON r1.rental_id = p1.rental_id
INNER JOIN public.inventory AS i1
	ON i1.inventory_id = r1.inventory_id
INNER JOIN public.film AS f1
	ON i1.film_id = f1.film_id
INNER JOIN public.film_category AS fc1
	ON fc1.film_id = f1.film_id
WHERE fc1.film_id IN (
	SELECT
		fc2.film_id
	FROM public.payment AS p2
	INNER JOIN public.rental AS r2
		ON r2.rental_id = p2.rental_id
	INNER JOIN public.inventory AS i2
		ON i2.inventory_id = r2.inventory_id
	INNER JOIN public.film AS f2
		ON i2.film_id = f2.film_id
	INNER JOIN public.film_category AS fc2
		ON fc2.film_id = f2.film_id
	where fc1.category_id = fc2.category_id
	GROUP BY fc2.film_id
    ORDER BY COUNT(r2.rental_id) DESC
    LIMIT 5
)
GROUP BY
	fc1.category_id,
	f1.film_id,
	f1.title
ORDER BY fc1.category_id


-- Develop a query that automatically updates the top 10 most frequently rented films,
-- considering a rolling 3-month window.
SELECT
	i.film_id,
	COUNT(r.rental_id) AS top_rented
FROM public.rental AS r
INNER JOIN public.inventory AS i
	ON r.inventory_id = i.inventory_id
WHERE 
	(EXTRACT(YEAR FROM CURRENT_TIMESTAMP) * 12 + EXTRACT(MONTH FROM CURRENT_TIMESTAMP)
	- (EXTRACT(YEAR FROM rental_date) * 12 + EXTRACT(MONTH FROM rental_date)))< 3
GROUP BY
		film_id
ORDER BY
		COUNT(r.rental_id) DESC
LIMIT 10


-- Identify stores where the revenue from film rentals exceeds the revenue from payments for all customers.
DROP table IF EXISTS temp_customer_payments;
CREATE TEMPORARY TABLE temp_customer_payments AS
(
	SELECT SUM(p.amount) AS total_cust_payments
FROM public.store AS s
INNER JOIN public.customer AS cu
	ON s.store_id = cu.store_id
INNER JOIN public.payment as p
	ON p.customer_id = cu.customer_id
);

DROP table IF EXISTS temp_rental_payments;
CREATE TEMPORARY TABLE temp_rental_payments AS
(
	SELECT s.store_id, SUM(p.amount) as total_rental_payments
	FROM public.store AS s
	INNER JOIN public.staff AS st
		ON s.store_id = st.store_id
	INNER JOIN public.payment as p
		ON p.staff_id = st.staff_id
	INNER JOIN public.rental as r
		ON r.rental_id = p.rental_id
	GROUP BY s.store_id
);
SELECT temp_rental_payments.store_id
FROM temp_rental_payments, temp_customer_payments
WHERE temp_rental_payments.total_rental_payments > temp_customer_payments.total_cust_payments


-- Determine the average rental duration and total revenue for each store,
-- considering different payment methods.
DROP TABLE IF EXISTS temp_payment_by_customer;
CREATE TEMPORARY TABLE temp_payment_by_customer AS
(
	SELECT
		s.store_id,
		AVG(r.return_date - r.rental_date) AS avg_rental_duration,
    	SUM(p.amount) AS total_payments
	FROM public.payment p
	INNER JOIN rental AS r
		ON p.rental_id = r.rental_id
	INNER JOIN public.inventory AS i
		ON r.inventory_id = i.inventory_id
	INNER JOIN public.store AS s
		ON i.store_id = s.store_id
	INNER JOIN public.customer AS c
		ON r.customer_id = c.customer_id
	GROUP BY
		s.store_id
);
CREATE INDEX indx_cust ON temp_payment_by_customer(store_id);

--Let's use the replacement cost table we created in part 6 too
WITH CTE_rep_cost AS
(
	SELECT
		s.store_id,
		SUM(f.replacement_cost) AS total_rep_cost
	FROM
		public.store AS s
	INNER JOIN public.staff AS st
		ON s.store_id = st.store_id
	INNER JOIN public.rental AS r
		ON st.staff_id = r.staff_id
	INNER JOIN public.inventory AS i
		ON r.inventory_id = i.inventory_id
	INNER JOIN public.film AS f
		ON i.film_id = f.film_id
	WHERE
		r.return_date IS NULL 
		AND r.rental_date + (f.rental_duration * INTERVAL '1 day') < CURRENT_TIMESTAMP
	GROUP BY
		s.store_id
)
SELECT
	tempo.store_id,
	tempo.total_payments + cte.total_rep_cost AS total_revenue
FROM temp_payment_by_customer AS tempo
FULL JOIN CTE_rep_cost AS cte
	ON tempo.store_id = cte.store_id


-- Analyze the seasonal variation in rental activity and payments for each store.
SELECT
    s.store_id,
    EXTRACT(YEAR FROM r.rental_date) AS year,
    EXTRACT(MONTH FROM r.rental_date) AS month,
    COUNT(r.rental_id) AS rental_count,
	SUM(p.amount) AS total_payment
FROM public.rental AS r
INNER JOIN public.inventory AS i
	ON r.inventory_id = i.inventory_id
INNER JOIN public.store AS s
	ON i.store_id = s.store_id
INNER JOIN public.payment AS p
	ON p.rental_id = r.rental_id
GROUP BY
	s.store_id,
	year,
	month
ORDER BY
	s.store_id,
	year,
	month
	
-- Analysis:
-- We tend to have more frequent rentals in the second half of the year,
-- and surely enough bigger total payments mainly in Summer months (June, July, August),
-- than in the first half, specifically in Februray.



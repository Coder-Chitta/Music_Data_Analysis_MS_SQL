create database music_database;

use music_database;

-- Analyzing Each Table
EXEC sp_columns album;           -- Primary Key album_id 
EXEC sp_columns artist;          -- Primary Key artist_id
EXEC sp_columns customer;        -- Primary Key customer_id
EXEC sp_columns employee;        -- Primary Key employye_id
EXEC sp_columns genre;           -- Primary Key genre_id
EXEC sp_columns invoice;         -- Primary Key invoice_id
EXEC sp_columns invoice_line;    -- Primary Key invoice_line_id
EXEC sp_columns media_type;      -- Primary Key media_type_id
EXEC sp_columns playlist;        -- Primary Key playlist_id
EXEC sp_columns playlist_track;  -- Primary Key playlist_id & track_id
EXEC sp_columns track;           -- Primary Key track_id


-- Q1: Who is the senior most employee based on job title? 
SELECT Top 1 title, concat(first_name, last_name) as fullname
FROM employee
ORDER BY levels DESC;


-- Q2: Which countries have the most Invoices? 
SELECT COUNT(*) AS country, billing_country 
FROM invoice
GROUP BY billing_country
ORDER BY country DESC;


-- Q3: What are top 3 values of total invoice?
SELECT top 3 round(total, 2)
FROM invoice
ORDER BY total DESC;


-- Q4: Which 2 city has the best customers? We would like to throw a promotional Music Festival in the city we made the most money.Write a query that returns one city that has the highest sum of invoice totals.Return both the city name & sum of all invoice totals 
SELECT top 2 billing_city,SUM(total) AS InvoiceTotal
FROM invoice
GROUP BY billing_city
ORDER BY InvoiceTotal DESC;


-- Q5: Who is the best customer? The customer who has spent the most money will be declared the best customer. Write a query that returns the person who has spent the most money.
SELECT TOP 1 WITH TIES
    customer.customer_id,
    first_name,
    last_name,
    SUM(total) AS total_spending
FROM customer
JOIN invoice ON customer.customer_id = invoice.customer_id
GROUP BY customer.customer_id, first_name, last_name
ORDER BY total_spending DESC;


-- Q6: Write query to return the email, first name, last name, & Genre of all Rock Music listeners. Return your list ordered alphabetically by email starting with A.
SELECT DISTINCT c.email, c.first_name, c.last_name
FROM customer AS c
JOIN invoice AS i ON c.customer_id = i.customer_id
JOIN invoice_line AS il ON i.invoice_id = il.invoice_id
WHERE il.track_id IN (
    SELECT t.track_id
    FROM track AS t
    JOIN genre AS g ON t.genre_id = g.genre_id
    WHERE g.name LIKE 'Rock'
)
ORDER BY c.email;


-- Q7: Let's invite the artists who have written the most rock music in our dataset. Write a query that returns the Artist name and total track count of the top 10 rock bands. */
SELECT TOP 10 artist.artist_id, artist.name, COUNT(artist.artist_id) AS number_of_songs
FROM track
JOIN album ON album.album_id = track.album_id
JOIN artist ON artist.artist_id = album.artist_id
JOIN genre ON genre.genre_id = track.genre_id
WHERE genre.name LIKE 'Rock'
GROUP BY artist.artist_id, artist.name
ORDER BY number_of_songs DESC;


-- Q8: Return all the track names that have a song length longer than the average song length. Return the Name and Milliseconds for each track. Order by the song length with the longest songs listed first. */
SELECT name, milliseconds
FROM track
WHERE milliseconds > (
    SELECT AVG(milliseconds) AS avg_track_length
    FROM track
)
ORDER BY milliseconds DESC;


-- Q9: Retrieve the names of artists who have albums containing more than 10 tracks, and for each artist, list the album names and the total number of tracks in each album. Sort the result by the total number of tracks in descending order
SELECT artist.name AS artist_name, album.title AS album_title, COUNT(track.track_id) AS total_tracks
FROM artist
JOIN album ON artist.artist_id = album.artist_id
JOIN track ON album.album_id = track.album_id
GROUP BY artist.artist_id, artist.name, album.album_id, album.title
HAVING COUNT(track.track_id) > 10
ORDER BY total_tracks DESC;


-- Q10: Retrieve the names of all artists and the total number of tracks they have in the database, ordered by the number of tracks in descending order.
SELECT
    artist.name AS artist_name,
    COUNT(track.track_id) AS total_tracks
FROM artist
LEFT JOIN album ON artist.artist_id = album.artist_id
LEFT JOIN track ON album.album_id = track.album_id
GROUP BY artist.name
ORDER BY total_tracks DESC;


-- Q11: Find how much amount spent by each customer on artists? Write a query to return customer name, artist name and total spent.
-- Steps to Solve: First, find which artist has earned the most according to the InvoiceLines. Now use this artist to find which customer spent the most on this artist. For this query, you will need to use the Invoice, InvoiceLine, Track, Customer, Album, and Artist tables. Note, this one is tricky because the Total spent in the Invoice table might not be on a single product, so you need to use the InvoiceLine table to find out how many of each product was purchased, and then multiply this by the pricefor each artist.

WITH best_selling_artist AS (
    SELECT TOP 1
        artist.artist_id AS artist_id,
        artist.name AS artist_name,
        SUM(invoice_line.unit_price * invoice_line.quantity) AS total_sales
    FROM invoice_line
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN album ON album.album_id = track.album_id
    JOIN artist ON artist.artist_id = album.artist_id
    GROUP BY artist.artist_id, artist.name
    ORDER BY total_sales DESC
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    bsa.artist_name,
    SUM(il.unit_price * il.quantity) AS amount_spent
FROM invoice i
JOIN customer c ON c.customer_id = i.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN album alb ON alb.album_id = t.album_id
JOIN best_selling_artist bsa ON bsa.artist_id = alb.artist_id
GROUP BY c.customer_id, c.first_name, c.last_name, bsa.artist_name
ORDER BY amount_spent DESC;


-- Q12: We want to find out the most popular music Genre for each country. We determine the most popular genre as the genre with the highest amount of purchases. Write a query that returns each country along with the top Genre. For countries where the maximum number of purchases is shared return all Genres.
-- Steps to Solve:  There are two parts in question- first most popular music genre and second need data at country level.

-- Method 1: Using CTE
WITH popular_genre AS 
(
    SELECT 
        COUNT(invoice_line.quantity) AS purchases, 
        customer.country, 
        genre.name AS popular_genre
    FROM invoice_line 
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
)
SELECT 
    country, 
    popular_genre
FROM (
    SELECT 
        country, 
        popular_genre,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY purchases DESC) AS RowNo
    FROM popular_genre
) ranked_genres
WHERE RowNo = 1;


-- Method 2: Using Recursive
WITH sales_per_country AS (
    SELECT
        COUNT(*) AS purchases_per_genre,
        customer.country,
        genre.name AS popular_genre
    FROM invoice_line
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
),
max_genre_per_country AS (
    SELECT
        MAX(purchases_per_genre) AS max_genre_number,
        country
    FROM sales_per_country
    GROUP BY country
)

SELECT
    sales_per_country.country,
    sales_per_country.popular_genre
FROM sales_per_country
JOIN max_genre_per_country ON sales_per_country.country = max_genre_per_country.country
WHERE sales_per_country.purchases_per_genre = max_genre_per_country.max_genre_number;


-- Q13: Write a query that determines the customer that has spent the most on music for each country. Write a query that returns the country along with the top customer and how much they spent.For countries where the top amount spent is shared, provide all customers who spent this amount.
-- Steps to Solve:  Similar to the above question. There are two parts in question- first find the most spent on music for each country and second filter the data for respective customers.

-- Method 1: using CTE
WITH CustomersWithCountry AS (
    SELECT
        customer.customer_id,
        first_name,
        last_name,
        billing_country,
        SUM(total) AS total_spending,
        ROW_NUMBER() OVER (PARTITION BY billing_country ORDER BY SUM(total) DESC) AS RowNo
    FROM invoice
    JOIN customer ON customer.customer_id = invoice.customer_id
    GROUP BY customer.customer_id, first_name, last_name, billing_country
)

SELECT
    billing_country,
    customer_id,
    first_name,
    last_name,
    total_spending
FROM CustomersWithCountry
WHERE RowNo = 1
UNION ALL
SELECT
    billing_country,
    customer_id,
    first_name,
    last_name,
    total_spending
FROM CustomersWithCountry
WHERE RowNo = 1
ORDER BY billing_country, total_spending DESC;


-- Method 2: Using Recursive
WITH CustomterWithCountry AS (
    SELECT
        customer.customer_id,
        first_name,
        last_name,
        billing_country,
        SUM(total) AS total_spending
    FROM invoice
    JOIN customer ON customer.customer_id = invoice.customer_id
    GROUP BY customer.customer_id, first_name, last_name, billing_country
),
CountryMaxSpending AS (
    SELECT
        billing_country,
        MAX(total_spending) AS max_spending
    FROM CustomterWithCountry
    GROUP BY billing_country
)

SELECT
    cc.billing_country,
    cc.total_spending,
    cc.first_name,
    cc.last_name,
    cc.customer_id
FROM CustomterWithCountry cc
JOIN CountryMaxSpending ms
ON cc.billing_country = ms.billing_country
WHERE cc.total_spending = ms.max_spending
ORDER BY cc.billing_country;


-- Q14: View that represents the most popular music genre for each country
CREATE VIEW MostPopularGenreByCountry AS
WITH PopularGenreByCountry AS (
    SELECT
        customer.country,
        genre.name AS popular_genre,
        COUNT(invoice_line.quantity) AS purchases
    FROM invoice_line
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
)

SELECT
    country,
    popular_genre
FROM (
    SELECT
        country,
        popular_genre,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY purchases DESC) AS RowNo
    FROM PopularGenreByCountry
) ranked_genres
WHERE RowNo = 1;


SELECT *
FROM MostPopularGenreByCountry;


-- Q15: Total number of purchases for each genre in each country
CREATE VIEW MostPopularGenreByCountryWithDetails AS
WITH PopularGenreByCountry AS (
    SELECT
        customer.country,
        genre.name AS popular_genre,
        COUNT(invoice_line.quantity) AS purchases
    FROM invoice_line
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
)

SELECT
    country,
    popular_genre,
    MAX(purchases) AS max_purchases,
    SUM(purchases) AS total_purchases
FROM PopularGenreByCountry
GROUP BY country, popular_genre;


SELECT *
FROM MostPopularGenreByCountryWithDetails;

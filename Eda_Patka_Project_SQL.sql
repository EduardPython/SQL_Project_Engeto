/* TABLE 1 - Ceny potravin  a prùmìrné mzdy v ÈR sjednotím na totožné porovnatelné období – INNER JOIN =>spoleèné roky (2006 - 2018) */
CREATE OR REPLACE TABLE t_eda_patka_project_SQL_primary_final AS 
SELECT 
	cpc.code,
	cpc.name AS food_category,
	cpc.price_value,
	cpc.price_unit,
	cp.value AS price,
	cp.date_from,
	cp.date_to,
	cpay.payroll_year ,
	cpay.value AS avg_wages,
	cpib.name AS industry
FROM czechia_price cp
JOIN czechia_payroll cpay 
	ON YEAR(cp.date_from) = cpay.payroll_year
	AND cpay.value_type_code = 5958
	AND cp.region_code IS NULL
JOIN czechia_price_category cpc 
	ON cp.category_code = cpc.code 
JOIN czechia_payroll_industry_branch cpib 
	ON cpay.industry_branch_code = cpib.code;



/* TABLE 2 - Dodateèná data o dalších evropských státech (2006 - 2018) */
CREATE OR REPLACE TABLE t_eda_patka_project_SQL_secondary_final AS 
SELECT 
	c.country,
	e.`year`,
	e.population, 
	e.GDP,
	e.gini
FROM countries c
JOIN economies e ON e.country = c.country
	WHERE c.continent = 'Europe'
		AND e.`year` BETWEEN 2006 AND 2018
ORDER BY c.`country`, e.`year`;


/*
 * 1.	Rostou v prùbìhu let mzdy ve všech odvìtvích, nebo v nìkterých klesají?
 */ 

-- VIEW Prùmìrné mzdy dle odvìtví a rokù
CREATE OR REPLACE VIEW v_eda_patka_project_avg_wages_yearly AS 
SELECT 
	DISTINCT	industry,
	payroll_year,
	round(avg(avg_wages)) AS avg_wages_yearly_CZK
FROM t_eda_patka_project_sql_primary_final tab1
GROUP BY industry, payroll_year
ORDER BY industry;

-- VIEW Trend rùstu mezd dle odvìtví a rokù 
CREATE OR REPLACE VIEW v_eda_patka_project_que_1_wage_growth_trend_by_sector_and_year AS 
SELECT
	DISTINCT newer_avg.industry, 
	older_avg.payroll_year AS older_year,
	older_avg.avg_wages_yearly_CZK AS older_wages,
	newer_avg.payroll_year,
	newer_avg.avg_wages_yearly_CZK AS avg_wages,
	round(newer_avg.avg_wages_yearly_CZK / older_avg.avg_wages_yearly_CZK, 4) AS ratio,
	CASE
		WHEN newer_avg.avg_wages_yearly_CZK > older_avg.avg_wages_yearly_CZK
			THEN 'UP'
			ELSE 'DOWN'
	END AS wages_trend
FROM v_eda_patka_project_avg_wages_yearly newer_avg
JOIN v_eda_patka_project_avg_wages_yearly older_avg
	ON newer_avg.industry = older_avg.industry
	AND newer_avg.payroll_year = older_avg.payroll_year +1
ORDER BY industry,payroll_year;

--  Z celkových 228 mìøení je 23 výsledkù DOWN (mzda klesla)
SELECT *
FROM v_eda_patka_project_que_1_wage_growth_trend_by_sector_and_year
WHERE ratio < 1;




/*
 * 2.  Kolik je možné si koupit litrù mléka a kilogramù chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
 */
-- VIEW Porovnání min. a max. year u srovnatelného období, které je od 2006 do 2018

/* Porovnával jsem celkovou prùmìrnou mzdu v ÈR bez ohledu na jednotlivá odvìtví. 
Výsledek slouží k porovnání prùmìrné kupní síly obyvatel ÈR  v definovaných letech. 
V roce 2006 byla prùmìrná mzda 20 754 Kè, prùmìrná cena chleba 16,12 Kè a prùmìrná cena mléka 14,44 Kè.. 
Teoreticky bylo možné z jedné výplaty nakoupit 1287 kg chleba nebo 1437 l mléka.
V roce 2018 byla prùmìrná mzda 32 536 Kè, prùmìrná cena chleba 24,24 Kè a prùmìrná cena mléka 19,82 Kè.. 
Teoreticky bylo možné z jedné výplaty nakoupit 1342 kg chleba nebo 1642 l mléka.
Z dat vyplývá, že v roce 2018 byla kupní síla obyvatel vyšší než v roce 2006.
*/
CREATE OR REPLACE VIEW v_eda_patka_project_que_2_purchasing_power_milk_bread AS 
SELECT
	food_category,
	price_value,
	price_unit,
	payroll_year,
	round(avg(price), 2) AS avg_price,
	round(avg(avg_wages)) AS avg_wages,
	round(avg(avg_wages) / avg(price)) AS units_can_be_purchased
FROM t_eda_patka_project_sql_primary_final
WHERE  code IN ('111301', '114201')
AND payroll_year IN ('2006', '2018')
GROUP BY food_category, payroll_year;

























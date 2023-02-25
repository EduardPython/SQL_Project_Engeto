/* TABLE 1 - Ceny potravin  a pr�m�rn� mzdy v �R sjednot�m na toto�n� porovnateln� obdob� � INNER JOIN =>spole�n� roky (2006 - 2018) */
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



/* TABLE 2 - Dodate�n� data o dal��ch evropsk�ch st�tech (2006 - 2018) */
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
 * 1.	Rostou v pr�b�hu let mzdy ve v�ech odv�tv�ch, nebo v n�kter�ch klesaj�?
 */ 

-- VIEW Pr�m�rn� mzdy dle odv�tv� a rok�
CREATE OR REPLACE VIEW v_eda_patka_project_avg_wages_yearly AS 
SELECT 
	DISTINCT	industry,
	payroll_year,
	round(avg(avg_wages)) AS avg_wages_yearly_CZK
FROM t_eda_patka_project_sql_primary_final tab1
GROUP BY industry, payroll_year
ORDER BY industry;

-- VIEW Trend r�stu mezd dle odv�tv� a rok� 
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

--  Z celkov�ch 228 m��en� je 23 v�sledk� DOWN (mzda klesla)
SELECT *
FROM v_eda_patka_project_que_1_wage_growth_trend_by_sector_and_year
WHERE ratio < 1;




/*
 * 2.  Kolik je mo�n� si koupit litr� ml�ka a kilogram� chleba za prvn� a posledn� srovnateln� obdob� v dostupn�ch datech cen a mezd?
 */
-- VIEW Porovn�n� min. a max. year u srovnateln�ho obdob�, kter� je od 2006 do 2018

/* Porovn�val jsem celkovou pr�m�rnou mzdu v �R bez ohledu na jednotliv� odv�tv�. 
V�sledek slou�� k porovn�n� pr�m�rn� kupn� s�ly obyvatel �R  v definovan�ch letech. 
V roce 2006 byla pr�m�rn� mzda 20 754 K�, pr�m�rn� cena chleba 16,12 K� a pr�m�rn� cena ml�ka 14,44 K�.. 
Teoreticky bylo mo�n� z jedn� v�platy nakoupit 1287 kg chleba nebo 1437 l ml�ka.
V roce 2018 byla pr�m�rn� mzda 32 536 K�, pr�m�rn� cena chleba 24,24 K� a pr�m�rn� cena ml�ka 19,82 K�.. 
Teoreticky bylo mo�n� z jedn� v�platy nakoupit 1342 kg chleba nebo 1642 l ml�ka.
Z dat vypl�v�, �e v roce 2018 byla kupn� s�la obyvatel vy��� ne� v roce 2006.
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

























/*
 * TABLE 1 - Ceny potravin a průměrné mzdy v ČR sjednotím na totožné porovnatelné období 
 * výsledkem jsou společné roky (2006–2018) 
 */

SELECT * FROM czechia_price ORDER BY date_from;
SELECT * FROM czechia_payroll ORDER BY payroll_year;	
-- Tabulky cen potravin a průměrných mezd se prolínají v letech 2006 - 2018

CREATE OR REPLACE TABLE t_eda_patka_project_SQL_primary_final AS 
SELECT 
	cpc.name AS food_category,
	cpc.price_value,
	cpc.price_unit,
	cp.value AS price,
	cp.date_from,
	cp.date_to,
	cpay.payroll_year ,
	cpay.value AS avg_wages,
	cpib.name AS industry_branch
FROM czechia_price cp
JOIN czechia_payroll cpay 
	ON YEAR(cp.date_from) = cpay.payroll_year
	AND cpay.value_type_code = 5958
	AND cp.region_code IS NULL
JOIN czechia_price_category cpc 
	ON cp.category_code = cpc.code 
JOIN czechia_payroll_industry_branch cpib 
	ON cpay.industry_branch_code = cpib.code;

SELECT * FROM t_eda_patka_project_sql_primary_final
ORDER BY date_from, food_category;


/* 
 * TABLE 2 - Dodatečná data o dalších evropských státech (2006–2018) 
 */

CREATE OR REPLACE TABLE t_eda_patka_project_SQL_secondary_final AS 
SELECT 
	c.country,
	e.`year`,
	e.population, 
	e.gini,
	e.GDP	
FROM countries c
JOIN economies e ON e.country = c.country
	WHERE c.continent = 'Europe'
		AND e.`year` BETWEEN 2006 AND 2018
ORDER BY c.`country`, e.`year`;

SELECT * FROM t_eda_patka_project_sql_secondary_final;


/*
 * 1.	Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
 */

-- VIEW Průměrné mzdy podle odvětví a roků
CREATE OR REPLACE VIEW v_eda_patka_project_avg_wages_by_sector_and_year AS 
SELECT 
	industry_branch,
	payroll_year,
	round(avg(avg_wages)) AS avg_wages_CZK
FROM t_eda_patka_project_sql_primary_final
GROUP BY industry_branch, payroll_year
ORDER BY industry_branch;

SELECT * FROM v_eda_patka_project_avg_wages_by_sector_and_year;

-- VIEW Trend růstu mezd dle odvětví a roků v CZK a v % 
CREATE OR REPLACE VIEW v_eda_patka_project_wages_growth_trend_by_sector_and_year AS 
SELECT
	newer_avg.industry_branch, 
	older_avg.payroll_year AS older_year,
	older_avg.avg_wages_CZK AS older_wages,
	newer_avg.payroll_year AS newer_year,
	newer_avg.avg_wages_CZK AS newer_wages,
	newer_avg.avg_wages_CZK - older_avg.avg_wages_CZK AS wages_difference_czk,
	round(newer_avg.avg_wages_CZK * 100 / older_avg.avg_wages_CZK, 2) - 100 AS wages_difference_percentage,
	CASE
		WHEN newer_avg.avg_wages_CZK > older_avg.avg_wages_CZK
			THEN 'UP'
			ELSE 'DOWN'
	END AS wages_trend
FROM v_eda_patka_project_avg_wages_by_sector_and_year AS newer_avg
JOIN v_eda_patka_project_avg_wages_by_sector_and_year AS older_avg
	ON newer_avg.industry_branch = older_avg.industry_branch
	AND newer_avg.payroll_year = older_avg.payroll_year +1
ORDER BY industry_branch;

SELECT * FROM v_eda_patka_project_wages_growth_trend_by_sector_and_year;
-- Mzdy ve všech sledovaných odvětvích od roku 2006 do roku 2018 rostou. Nicméně růst mezd nebyl lineární a v některých letech byl zaznamenán meziroční pokles.

-- MEZIROČNÍ POKLES MEZD
SELECT *
FROM v_eda_patka_project_wages_growth_trend_by_sector_and_year
WHERE wages_trend = 'DOWN'
ORDER BY wages_difference_percentage;
-- Největší meziroční pokles zaznamenalo odvětví Peněžnictví a pojišťovnictví v roce 2013, kdy se průměrná mzda snížila o -8,91 % z 50 254 Kč v roce 2012 na 45 775 Kč v roce 2013.
-- Z celkových 228 měření byl pokles mzdy zaznamenán u 23 výsledků, což představuje přibližně 10 % ze všech měření.

-- PRŮMĚRNÁ MĚSÍČNÍ MZDA. Porovnání let 2006 a 2018 podle odvětví
SELECT *
FROM v_eda_patka_project_avg_wages_by_sector_and_year
WHERE payroll_year IN (2006, 2018);

-- MZDOVÝ NÁRŮST CELKEM od roku 2006 do roku 2018 podle odvětví v %  
SELECT
	newer_avg.industry_branch, 
	older_avg.payroll_year AS older_year,
	older_avg.avg_wages_CZK AS older_wages,
	newer_avg.payroll_year AS newer_year,
	newer_avg.avg_wages_CZK AS newer_wages,
	newer_avg.avg_wages_CZK - older_avg.avg_wages_CZK AS wages_difference_czk,
	round(newer_avg.avg_wages_CZK * 100 / older_avg.avg_wages_CZK, 2) - 100 AS wages_difference_percentage
FROM v_eda_patka_project_avg_wages_by_sector_and_year AS newer_avg
JOIN v_eda_patka_project_avg_wages_by_sector_and_year AS older_avg
	ON newer_avg.industry_branch = older_avg.industry_branch
		WHERE older_avg.payroll_year = 2006 
			AND newer_avg.payroll_year = 2018
ORDER BY round(newer_avg.avg_wages_CZK * 100 / older_avg.avg_wages_CZK, 2) - 100 DESC;
-- Největším nárůstem mezd se pyšní odvětví Zdravotní a sociální péče, kde byla v roce 2018 průměrná mzda o 76,9 % vyšší než v roce 2006. Nejmenší nárůst mezd byl zaznamenán v odvětví Peněžnictví a pojišťovnictví, kde byla v roce 2018 průměrná mzda o 36,3 % vyšší než v roce 2006.

/*
 * 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
 */

-- Kupní síla obyvatel pro ČR v letech 2006 a 2018 vzhledem k cenám chleba a mléka.
SELECT
	food_category, price_value, price_unit, payroll_year,
	round(avg(price), 2) AS 'avg_price',
	round(avg(avg_wages), 2) AS 'avg_wages',
	round((round(avg(avg_wages), 2)) / (round(avg(price), 2))) AS avg_purchasing_power
FROM t_eda_patka_project_sql_primary_final
WHERE payroll_year IN(2006, 2018)
	AND food_category IN('Mléko polotučné pasterované', 'Chléb konzumní kmínový')
GROUP BY food_category, payroll_year;
-- V roce 2006 bylo za průměrnou cenu chleba 16,12 Kč a průměrnou mzdu 20 753,78 Kč možné nakoupit 1 287,18 kg chleba a 1 437 l mléka za cenu 14,44 Kč. V roce 2018 bylo za cenu 24,24 Kč a průměrnou mzdu 32 536 Kč možné nakoupit 1 342 kg chleba a 1 642 l mléka za průměrnou cenu 19,82 Kč. 

-- dtto podle odvětví
SELECT
	industry_branch,
	food_category, price_value, price_unit, payroll_year,
	round(avg(price), 2) AS avg_price,
	round(avg(avg_wages), 2) AS avg_wages,
	round((round(avg(avg_wages), 2)) / (round(avg(price), 2))) AS avg_purchasing_power
FROM t_eda_patka_project_sql_primary_final
WHERE payroll_year IN(2006, 2018)
	AND food_category IN('Mléko polotučné pasterované',  'Chléb konzumní kmínový')
GROUP BY industry_branch, food_category, payroll_year;

-- dtto podle kategorie potravin a odvětví, seřazené podle kupní síly
SELECT
	food_category, price_value, price_unit, payroll_year,
	round(avg(price), 2) AS avg_price,
	round(avg(avg_wages), 2) AS avg_wages,
	round((round(avg(avg_wages), 2)) / (round(avg(price), 2))) AS avg_purchasing_power,
	industry_branch
FROM t_eda_patka_project_sql_primary_final
WHERE payroll_year IN(2006, 2018)
	AND food_category IN('Mléko polotučné pasterované',  'Chléb konzumní kmínový')
GROUP BY food_category, payroll_year, industry_branch
ORDER BY round((round(avg(avg_wages), 2)) / (round(avg(price), 2))) DESC;


/*
 * 3.	Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší procentuální meziroční nárůst)?
 */

-- VIEW Roční průměrná cena potravin
CREATE OR REPLACE VIEW v_eda_patka_project_avg_food_price_by_year AS 
SELECT 
	DISTINCT food_category,
	price_value AS value, 
	price_unit AS unit, 
	payroll_year AS year, 
	round(avg(price), 2) AS avg_price
FROM t_eda_patka_project_sql_primary_final
GROUP BY food_category, payroll_year;

SELECT * FROM v_eda_patka_project_avg_food_price_by_year;

-- VIEW Cenový trend potravin od roku 2006 do roku 2018
CREATE OR REPLACE VIEW v_eda_patka_project_food_price_trend AS 
SELECT 
	DISTINCT older_year.food_category, 
	older_year.value,
	older_year.unit,
	older_year.`year` AS older_year,
	older_year.avg_price AS older_price,
	newer_year.`year` AS newer_year,
	newer_year.avg_price AS newer_price, 
	newer_year.avg_price - older_year.avg_price AS price_difference_czk,
	round((newer_year.avg_price - older_year.avg_price) / older_year.avg_price * 100, 2) AS price_diff_percentage,
	CASE
		WHEN newer_year.avg_price > older_year.avg_price
		THEN 	'up'
		ELSE 'down'
	END AS price_trend
FROM v_eda_patka_project_avg_food_price_by_year AS older_year
JOIN v_eda_patka_project_avg_food_price_by_year AS newer_year 
	ON older_year.food_category = newer_year.food_category
		AND newer_year.`year` = older_year.`year`+1
ORDER BY food_category, older_year.`year`;

SELECT * FROM v_eda_patka_project_food_price_trend;

-- Průměrný meziroční nárůst cen potravin mezi roky 2006 - 2018
SELECT 
	older_year AS year_from,
	max(newer_year) AS year_to,
	food_category,
	round(avg(price_diff_percentage), 2) AS avg_annual_price_growth_in_percentage
FROM v_eda_patka_project_food_price_trend
GROUP BY food_category
ORDER BY round(avg(price_diff_percentage), 2) ;
-- Cukr krystalový patří mezi potravinové kategorie, jejichž cena se zvyšovala nejméně. Výsledky ukazují, že cena této kategorie se meziročně dokonce snižovala, a to průměrně o -1,92 %. V období od roku 2006 do roku 2018 se průměrná cena za 1 kg cukru postupně zvyšovala a klesala z původních 21,73 Kč v roce 2006, na konečných 15,75 Kč v roce 2018. Na druhé straně, největší meziroční procentuální nárůst byl zaznamenán u paprik. Jejich cena se zvyšovala průměrně  o 7,29 %.

-- HIGHES price difference
SELECT * FROM v_eda_patka_project_food_price_trend
ORDER BY price_diff_percentage DESC;
-- LOWEST price difference
SELECT * FROM v_eda_patka_project_food_price_trend
ORDER BY price_diff_percentage;
-- K největšímu meziročnímu zdražení v období let 2006 až 2018 došlo u paprik mezi lety 2006 až 2007, a naopak nejvíce zlevnila meziročně rajská jablka, bylo to rovněž v letech 2006 až 2007.

-- VIEW Průměrné ceny potravin - porovnání roků 2006 a 2018
CREATE OR REPLACE VIEW v_eda_patka_project_food_price_2006_compare_2018 AS 
SELECT 
	older_year.food_category,
	older_year.value,
	older_year.unit,
	older_year.`year` AS older_year,
	older_year.avg_price AS older_price,
	newer_year.`year` AS newer_year,
	newer_year.avg_price AS newer_price,
	newer_year.avg_price - older_year.avg_price AS price_diff_czk,
	round((newer_year.avg_price - older_year.avg_price) / older_year.avg_price *100, 2) AS price_diff_percentage
FROM v_eda_patka_project_avg_food_price_by_year AS older_year
JOIN v_eda_patka_project_avg_food_price_by_year AS newer_year
	ON older_year.food_category = newer_year.food_category
		WHERE older_year.`year` = 2006
			AND newer_year.`year` = 2018;
		
SELECT * FROM v_eda_patka_project_food_price_2006_compare_2018
ORDER BY price_diff_percentage DESC;
-- Nejvyšší procentuální nárůst ceny potravin, při porovnání roků 2006 a 2018, byl zaznamenán u másla, navýšení o 98,37 %. Následují vaječné těstoviny s 83,45 %, paprika s 71,25 % a rýže s 69,94 %. K výraznému zlevnění v období let 2006 až 2018 došlo u cukru a rajských jablek, s poklesem cen o -27,52 % a -23,07 %.


/*
 * 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
 */

SELECT * FROM v_eda_patka_project_avg_wages_by_sector_and_year;

-- VIEW Průměrná mzda v ČR v letech 2006 - 2018 (průměr ze všech odvětví dohromady)
CREATE OR REPLACE VIEW v_eda_patka_project_avg_wages_cr_2006_2018 AS 
SELECT 
	industry_branch, -- sloupec industry_branch je zde jen kvůli propojení v další tabulce
	payroll_year, 
	round(avg(avg_wages_CZK)) AS avg_wages_CR_CZK
FROM v_eda_patka_project_avg_wages_by_sector_and_year
GROUP BY payroll_year;

SELECT * FROM v_eda_patka_project_avg_wages_cr_2006_2018;

-- VIEW Trend vývoje růstu mezd v ČR v letech 2006 - 2018
CREATE OR REPLACE VIEW v_eda_patka_project_avg_wages_trend_diff_cr_2006_2018 AS 
SELECT
	awcr1.payroll_year AS older_year, 
	awcr1.avg_wages_CR_CZK AS older_wages,
	awcr2.payroll_year AS newer_year,
	awcr2.avg_wages_CR_CZK AS newer_wages,
	round((awcr2.avg_wages_CR_CZK - awcr1.avg_wages_CR_CZK) / awcr1.avg_wages_CR_CZK * 100, 2) AS avg_wages_diff_percentage
FROM v_eda_patka_project_avg_wages_cr_2006_2018 AS awcr1
JOIN v_eda_patka_project_avg_wages_cr_2006_2018 AS awcr2
	ON awcr2.industry_branch = awcr1.industry_branch 
		AND awcr2.payroll_year = awcr1.payroll_year + 1;

SELECT * FROM v_eda_patka_project_avg_wages_trend_diff_cr_2006_2018;

-- VIEW Půměrné ceny potravin v ČR v letech 2006 - 2018 (průměr ze všech kategorií dohromady)
CREATE OR REPLACE VIEW v_eda_patka_project_avg_food_price_cr_2006_2018 AS 
SELECT 
	food_category,	-- sloupec food_category je je zde jen kvůli propojení v další tabulce
	`year`,
	round(avg(avg_price), 2) AS avg_food_price_cr_czk
FROM v_eda_patka_project_avg_food_price_by_year
GROUP BY `year`;

SELECT * FROM v_eda_patka_project_avg_food_price_cr_2006_2018;

-- VIEW Trend vývoje růstu cen potravin v ČR v letech 2006 - 2018
CREATE OR REPLACE VIEW v_eda_patka_project_avg_food_price_trend_diff_cr_2006_2018 AS 
SELECT 
	afp1.`year`AS older_year, 
	afp1.avg_food_price_cr_czk AS older_price, 
	afp2.`year` AS newer_year, 
	afp2.avg_food_price_cr_czk AS newer_price,
	afp2.avg_food_price_cr_czk - afp1.avg_food_price_cr_czk AS avg_wages_diff_czk,
	round(avg(afp2.avg_food_price_cr_czk - afp1.avg_food_price_cr_czk) / afp1.avg_food_price_cr_czk * 100, 2) AS avg_price_diff_percentage
FROM v_eda_patka_project_avg_food_price_cr_2006_2018 AS afp1
JOIN v_eda_patka_project_avg_food_price_cr_2006_2018 AS afp2 
	ON afp2.food_category = afp1.food_category
		AND afp2.`year` = afp1.`year` + 1
GROUP BY afp1.`year`;

-- VIEW Porovnání meziročního nárůstu průměrných cen a mezd v ČR
CREATE OR REPLACE VIEW v_eda_patka_project_yoy_growth_prices_and_wages_comparison_in_CR AS 
SELECT 
	afptd.older_year, 
	awtd.newer_year,
	awtd.avg_wages_diff_percentage,
	afptd.avg_price_diff_percentage,
	afptd.avg_price_diff_percentage - awtd.avg_wages_diff_percentage AS price_wages_diff
FROM v_eda_patka_project_avg_food_price_trend_diff_cr_2006_2018 AS afptd
JOIN v_eda_patka_project_avg_wages_trend_diff_cr_2006_2018 AS awtd 
	ON awtd.older_year = afptd.older_year
GROUP BY afptd.older_year
ORDER BY afptd.avg_price_diff_percentage DESC;

SELECT * FROM v_eda_patka_project_yoy_growth_prices_and_wages_comparison_in_CR
ORDER BY price_wages_diff DESC;
-- V žádném z roků, které byly zkoumány, nepřesáhl meziroční nárůst potravin hranici 10 %. Největší meziroční nárůst potravin byl zaznamenán v roce 2017, a to ve výši 9,63 %. V roce 2013 byl zaznamenán nejvyšší rozdíl mezi nárůstem cen a mezd, a to ve výši 6,66 %. V tomto roce se ceny potravin oproti roku předchozímu zvýšily o 5,1 %, zatímco mzdy poklesly o -1,56 %. V roce 2010 dosáhl meziroční nárůst průměrných cen a mezd stejné úrovně.


/*
 * Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 
 * projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?
 */

-- VIEW HDP v ČR v letech 2006 - 2018
CREATE OR REPLACE VIEW v_eda_patka_project_gdp_cr_2006_2018 AS 
SELECT * FROM t_eda_patka_project_sql_secondary_final
WHERE country = 'Czech Republic';

SELECT * FROM v_eda_patka_project_gdp_cr_2006_2018;

-- VIEW HDP trend - meziroční vývoj
CREATE OR REPLACE VIEW v_eda_patka_project_yoy_gdp_trend_diff_cr_2006_2018 AS 
SELECT 
	gdp1.`year` AS older_year, 
	gdp1.GDP AS older_gdp, 
	gdp2.`year` AS newer_year, 
	gdp2.GDP AS newer_gdp,
	round(avg(gdp2.GDP - gdp1.GDP) / gdp1.GDP * 100, 2) AS gdp_diff_percentage
FROM v_eda_patka_project_gdp_cr_2006_2018 AS gdp1
JOIN v_eda_patka_project_gdp_cr_2006_2018 AS gdp2
	ON gdp2.country = gdp1.country
		AND gdp2.`year` = gdp1.`year` + 1
GROUP BY gdp1.`year`;

SELECT * FROM v_eda_patka_project_yoy_gdp_trend_diff_cr_2006_2018;

-- VIEW Meziroční vývoj Cen potravin, Mezd a HDP v ČR 2006-2018
CREATE OR REPLACE VIEW v_eda_patka_project_yoy_foodprice_wages_gdp_trend AS 
SELECT 
	gdp.older_year, 
	gdp.newer_year, 
	fpt.avg_price_diff_percentage, 
	wag.avg_wages_diff_percentage, 
	gdp.gdp_diff_percentage
FROM v_eda_patka_project_yoy_gdp_trend_diff_cr_2006_2018 AS gdp
JOIN v_eda_patka_project_avg_wages_trend_diff_cr_2006_2018 AS wag
	ON wag.older_year = gdp.older_year
JOIN v_eda_patka_project_avg_food_price_trend_diff_cr_2006_2018 AS fpt 
	ON fpt.older_year = gdp.older_year;

SELECT * FROM v_eda_patka_project_yoy_foodprice_wages_gdp_trend;
-- ORDER BY gdp_diff_percentage DESC;

-- Průměr meziročního růstu cen, mezd a HDP za celé období
SELECT 
	older_year AS year_from,
	max(newer_year) AS year_to,
	round(avg(avg_price_diff_percentage), 2) AS avg_foodprice_growth_trend_percentage, 
	round(avg(avg_wages_diff_percentage), 2) AS avg_wages_growth_trend_percentage, 
	round(avg(gdp_diff_percentage), 2) AS avg_gdp_growgh_trend_percentage
FROM v_eda_patka_project_yoy_foodprice_wages_gdp_trend;

-- Nárůst za celé období
SELECT 
	older_year AS year_from,
	max(newer_year) AS year_to,
	round(sum(avg_price_diff_percentage), 2) AS avg_foodprice_growth_trend_percentage, 
	round(sum(avg_wages_diff_percentage), 2) AS avg_wages_growth_trend_percentage, 
	round(sum(gdp_diff_percentage), 2) AS avg_gdp_growgh_trend_percentage
FROM v_eda_patka_project_yoy_foodprice_wages_gdp_trend;

-- Na základě analýzy průměrného růstu cen potravin, mezd a HDP v letech 2006–2018 nelze s jistotou potvrdit ani vyvrátit danou hypotézu. I když existuje jistá kauzalita, tato závislost se projevila nepravidelně a není jednoznačná pro všechny roky.
-- Například v roce 2015 je patrný výrazný růst HDP o 5,39 %, ale průměrné ceny potravin ve stejném i v následujícím roce klesaly. Na druhé straně v roce 2012 došlo ke snížení HDP, ale ceny potravin i mzdy v následujících letech rostly. V roce 2013 je vidět menší pokles HDP o -0,05 %, ale ceny potravin stouply a mzdy klesly. V roce 2009 došlo k výraznému poklesu HDP o -4,66 %, ale ceny potravin se naopak snížily a mzdy rostly.
-- Z dostupných dat lze tedy vyvodit, že výška HDP nemá jednoznačný vliv na změny cen potravin nebo platů. Průměrné ceny potravin, stejně jako průměrné mzdy, mohou stoupat i klesat nezávisle na vývoji HDP. 
-- V období od roku 2006 do 2018 převládaly mezi všemi sledovanými kategoriemi hodnoty meziročního růstu nad jejich poklesem. V případě HDP došlo ke třem meziročním poklesům, ceny potravin klesly ve dvou případech a mzdy klesly pouze v jednom roce. 
-- Průměrná roční rychlost růstu HDP mezi lety 2006 a 2018 byla 2,13 % a celkový nárůst za toto období činil 25,51 %. Ceny potravin stoupaly průměrně o 2,87 % ročně a celkově se zvýšily o 34,44 %. Mzdy pak rostly v průměru o 3,85 % ročně, celkově pak vzrostly o 46,22 %.

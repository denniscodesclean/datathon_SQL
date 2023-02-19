use datathon;
#data preparation
SELECT column_name, DATA_TYPE from INFORMATION_SCHEMA.COLUMNS where
table_schema = "datathon" and table_name = "sales";
	#date column format
UPDATE sales
SET date = STR_TO_DATE(date, "%m/%d/%Y %H:%ix");
	#add another date column without time
ALTER TABLE sales
ADD date1 date;
UPDATE sales
SET date1 = left(date, 10);
	#add a binary column of before or after operational change (4.11), 1:24hours / 0:12hours
ALTER TABLE sales
ADD all_day_operation int;
UPDATE sales
SET all_day_operation =
	case when date1 >= "2017-04-11" then 0
		else 1
	end;

#change of purchases behavior for 2017 & 2018
with table1 as (
select extract(year from date1) as year,
	count(distinct receipt_id) as orders,
	round(sum(total_selling_price),2) as revenue,
    round(sum(total_profit),2) as profit
from sales
group by 1),
	table2 as (
select year,
    sum(payment_type = "cash") as cash_orders,
    sum(payment_type = "magcard") as magcard_orders
from
 (Select receipt_id,
	 min(extract(year from date1)) as year,
     min(payment_type) as "payment_type"
	from sales
	group by 1) as temp
group by 1)
select *
from table1
inner join table2
using(year);

#change of purchase behavior befor and after the change (4months vs 20months)
with table1 as (
select all_day_operation,
	count(distinct receipt_id) as orders,
	round(sum(total_selling_price),2) as revenue,
    round(sum(total_profit),2) as profit
from sales
group by 1),
	table2 as (
select all_day_operation,
    sum(payment_type = "cash") as cash_orders,
    sum(payment_type = "magcard") as magcard_orders
from
 (Select receipt_id,
	 min(all_day_operation) as "all_day_operation",
     min(payment_type) as "payment_type"
	from sales
	group by 1) as temp
group by 1)
select *
from table1
inner join table2
using(all_day_operation);

#change of purchase behavior befor and after the change (4months vs 4 months)                        TABLE ONE
with table1 as (
select all_day_operation,
	count(distinct receipt_id) as orders,
	round(sum(total_selling_price),2) as revenue,
    round(sum(total_profit),2) as profit
from sales
where date1 <= "2018-04-11" and date1 not between "2017-04-12" and "2017-12-31"
group by 1),
	table2 as (
select all_day_operation,
    sum(payment_type = "cash") as cash_orders,
    sum(payment_type = "magcard") as magcard_orders
from
 (Select receipt_id,
	 min(all_day_operation) as "all_day_operation",
     min(payment_type) as "payment_type"
	from sales
    where date1 <= "2018-04-12" and date1 not between "2017-04-12" and "2017-12-31" #limit to  Jan-April in 2018 and 2017
	group by 1) as temp
group by 1)
select *
from table1
inner join table2
using(all_day_operation);
	
#change in categories (4months vs 4months)                                                          TABLE TWO
select *,
	round((orders_2 - orders_1)/orders_1,2) as percent_change
from
	(select temp1.year as year_1,
	temp1.main_category, 
	temp1.orders as orders_1,
	round(coalesce(temp2.year, 2018*2017/temp1.year),0) as year_2, #use coalesce to subtitue null values with another year
	round(coalesce(temp2.orders,0),0) as orders_2 #use coalesce to substitue null to 0
	from
		(select min(extract(year from date1)) as year, main_category, count(*) as orders
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), main_category
		order by 2,1 asc) as temp1
		left join 
		(select min(extract(year from date1)) as year, main_category, count(*) as orders
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), main_category
		order by 2,1 asc) as temp2
		on temp1.main_category = temp2.main_category and temp1.year != temp2.year
		where temp1.year = case when temp1.main_category = "Bag" then 2018
			else 2017
			end) as temp3;
# See the categories that were popular at non-operation time
#item
select item_name, min(sub_category), min(main_category), count(distinct receipt_id) as orders, sum(total_selling_price) as revenue
from sales
where all_day_operation = 1 and (extract(hour from date) between 0 and 6) or (extract(hour from date) between 19 and 23)
group by 1
order by count(distinct receipt_id) desc;
#category
select main_category, count(distinct receipt_id) as orders, round(sum(total_selling_price),0) as revenue
from sales
where all_day_operation = 1 and (extract(hour from date) between 0 and 6) or (extract(hour from date) between 19 and 23)
group by 1
order by count(distinct receipt_id) desc;


#sub categories decreased due to change in operartion time (rank high and percent change negative)
with cte as (select *,
	round((orders_2 - orders_1)/orders_1,2) as order_percent_change,
    round((profits_2 - profits_1)/profits_1,2) as profit_percent_change
from
	(select temp1.sub_category,
    temp1.year as year_1,
	temp1.orders as orders_1,
    round(temp1.profits,2) as profits_1,
	round(coalesce(temp2.year, 2018*2017/temp1.year),0) as year_2, #use coalesce to subtitue null values with another year
	round(coalesce(temp2.orders,0),0) as orders_2, #use coalesce to substitue null to 0
    round(coalesce(temp2.profits,0),0) as profits_2
	from
		(select min(extract(year from date1)) as year, sub_category, count(*) as orders, sum(total_selling_price)-sum(total_buying_price) as profits
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), sub_category
		order by 2,1 asc) as temp1
		left join 
		(select min(extract(year from date1)) as year, sub_category, count(*) as orders, sum(total_selling_price)-sum(total_buying_price) as profits
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), sub_category
		order by 2,1 asc) as temp2
		on temp1.sub_category= temp2.sub_category and temp1.year != temp2.year
		where temp1.year = 2017) as temp3),
	cte1 as (
		select sub_category, count(distinct receipt_id) as orders, round(sum(total_selling_price),0) as revenue
	from sales
	where all_day_operation = 1 and (extract(hour from date) between 0 and 6) or (extract(hour from date) between 19 and 23)
	group by 1
	order by count(distinct receipt_id) desc)
select *
from cte
right join cte1
using(sub_category)
order by revenue desc;

#items decreased due to change in operartion time (rank high and percent change negative)
with cte as (select *,
	round((orders_2 - orders_1)/orders_1,2) as order_percent_change,
    round((profits_2 - profits_1)/profits_1,2) as profit_percent_change
from
	(select temp1.item_name,
    temp1.year as year_1,
	temp1.orders as orders_1,
    round(temp1.profits,2) as profits_1,
	round(coalesce(temp2.year, 2018*2017/temp1.year),0) as year_2, #use coalesce to subtitue null values with another year
	round(coalesce(temp2.orders,0),0) as orders_2, #use coalesce to substitue null to 0
    round(coalesce(temp2.profits,0),0) as profits_2
	from
		(select min(extract(year from date1)) as year, item_name, count(*) as orders, sum(total_selling_price)-sum(total_buying_price) as profits
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), item_name
		order by 2,1 asc) as temp1
		left join 
		(select min(extract(year from date1)) as year, item_name, count(*) as orders, sum(total_selling_price)-sum(total_buying_price) as profits
		from sales
		where date1 <= "2018-04-12" and (date1 not between "2017-04-12" and "2017-12-31")
		group by extract(year from date1), item_name
		order by 2,1 asc) as temp2
		on temp1.item_name= temp2.item_name and temp1.year != temp2.year
		where temp1.year = 2017) as temp3),
	cte1 as (
		select item_name, count(distinct receipt_id) as orders, round(sum(total_selling_price),0) as revenue
	from sales
	where all_day_operation = 1 and (extract(hour from date) between 0 and 6) or (extract(hour from date) between 19 and 23)
	group by 1
	order by count(distinct receipt_id) desc)
select *
from cte
right join cte1
using(item_name)
order by revenue desc;

#sub categories analysis: profitability                                                             TABLE THREE (strategy move popular stuff to the deep side)
select sub_category, round(avg(unit_price_margin),2) as profit
from sales
group by 1
order by 2 desc; #this table needs to be combined with the basket analsis on tableau.
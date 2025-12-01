create database Manufacturing_Line_Productivity_Project
use Manufacturing_Line_Productivity_Project

   --***************************--

create table Line_Productivity (
Date Date,
Product varchar(20),
Batch varchar(20),
Operator varchar(20),
Start_Time time,
End_Time time,
Constraint Batch_Pk  primary key (Batch)
)

Bulk insert dbo.Line_Productivity
from 'C:\Users\Michael\Desktop\Manufacturing_Line_Productivity_Project.csv'
with (
format='CSV',
firstrow=2
)
Select * from Line_Productivity

   --***************************--

create table Products (
Product varchar(20),
Flavor varchar(20),
Size varchar(20),
Min_Batch_Time_mins int

constraint Product_Pk  primary key (Product)
)
Bulk insert dbo.Products
from 'C:\Users\Michael\Desktop\Manufacturing_Line_Productivity_Project.csv'
with (
format='CSV',
firstrow=2
)
Select * from Products

   --***************************--

create table Downtime_Factors (
Factor varchar(5),
Description varchar(30),
Operator_Error varchar(5),

Constraint Factor_Pk  primary key (Factor)
)

Bulk insert dbo.Downtime_Factors
from 'C:\Users\Michael\Desktop\Manufacturing_Line_Productivity_Project.csv'
with (
format='CSV',
firstrow=2
)
Select * from Downtime_Factors

   --***************************--

create table Line_Downtime (
Batch varchar(20),
Factor varchar(5),
Downtime_in_mins int ,
Description varchar(25),
Operator_Error varchar(5)

Constraint Batch_Factor_Pk primary key (Batch, Factor)
)

Bulk insert dbo.Line_Downtime
from 'C:\Users\Michael\Desktop\Manufacturing_Line_Productivity_Project.csv'
with (
format='CSV',
firstrow=2
)
Select * from Line_Downtime

--********* Adding Foreign Keys to make relationships *********--

Alter table Line_Productivity
add constraint Product_Fk Foreign Key (Product) references Products(Product)
  
Alter table Line_Downtime
add   constraint Factor_Fk Foreign Key (Factor) references Downtime_Factors(Factor)

Alter table Line_Downtime
add constraint Batch_Fk  Foreign Key (Batch) references Line_Productivity (Batch)


--********* Cleaning and EDA *********--
select * from Line_Productivity
select * from Products
select * from Downtime_Factors
select * from Line_Downtime

--Delete A Null Row for Making Batch column as a primary key 
Delete from dbo.Line_Downtime
where Batch = 0

--Changing Time Formating 
alter table Line_Productivity
alter column Start_time time(0)
alter table Line_Productivity
alter column End_time time(0)

--Adding calculated Column As Total Minutes
alter table Line_Productivity
add Total_Minutes as
case 
when End_Time >= Start_Time 
then datediff(minute, cast(Start_Time as datetime),cast(End_Time as datetime))
else datediff(minute, cast(Start_Time as datetime), dateadd(day,1,cast(End_Time as datetime)))
end

-- Adding calculated Column As Shifts
alter table Line_Productivity
add Shifts AS
case when Start_Time >='06:00:00' and Start_Time < '14:00:00' then'Morning'
     when Start_Time >='14:00:00' and Start_Time< '22:00:00' then'Afternoon'
     else 'Evening'
end 
--********* Insghits *********--
--A- Downtime analysis--

--1- What is the total downtime recorded?
select sum (Downtime_in_mins) as Total_Downtime
from Line_Downtime

--2- How many downtime events occurred?
select count(*) as Num_of_Downtime_Events
from Line_Downtime

--3- What is the total number of batches?
select count(*) as Total_Batches
from Line_Productivity

--4- What is the total scheduled production time? (batches time)
select sum (Total_Minutes) as Total_Scheduled_Production_Time_Mins
from Line_Productivity 

--5- How much time was actually spent producing?
select 
    sum(p.Min_Batch_Time_mins) as total_min_production_time_mins
from line_productivity lp
join products p 
    on lp.product = p.product;

--6- How does daily production volume change over time?
select Date, count(Batch) as Total_Batches
from Line_Productivity
group by date
order by date

--7- What is the average batch duration per product and operator?
select Product,Operator,avg(Total_Minutes) as Avg_Batch_Duration_Minutes    
from Line_Productivity
group by Product , Operator
order by Product, Operator

--8- Which operator consistently completes batches closest to the Min Batch Time?
select Min_Batch_Time_mins, lp.Operator,round(avg(abs(lp.Total_Minutes - p.Min_Batch_Time_mins)), 2) as Avg_Deviation_Minutes
from Line_Productivity lp join Products p 
on lp.Product = p.Product
group by lp.Operator , Min_Batch_Time_mins
order by Avg_Deviation_Minutes

--ABS(lp.Total_Minutes - p.Min_Batch_Time_mins) → calculates the difference (in minutes) between actual and target time for each batch.

--9- Which product–flavor–size combination shows the highest deviation from ideal performance?
select p.Product, p.Flavor,p.Size, round(avg(abs(lp.Total_Minutes - p.Min_Batch_Time_mins)), 2) as Avg_Deviation_Minutes,
    max(abs(lp.Total_Minutes - p.Min_Batch_Time_mins)) as Max_Deviation_Minutes,
    count(lp.Batch) as Total_Batches
from Line_Productivity lp
join Products p 
    on lp.Product = p.Product
group by p.Product, p.Flavor, p.Size
order by Avg_Deviation_Minutes desc

--10- Which products have the highest number of batches produced?
select Product,count(Batch) as Total_Batches
from Line_Productivity
group by Product
order by Total_Batches desc

--11- Which product has the most downtime? / 
select top 1 LP.Product,sum(LD.Downtime_in_mins) as Total_Downtime
FROM Line_Productivity LP join Line_Downtime LD on  LP.Batch = LD.Batch
group by LP.Product
order by Total_Downtime desc

--12- Which product consumes the most production time?
select top 1  Product, sum(Total_Minutes) as Total_Production_Time
from Line_Productivity
group by Product
order by Total_Production_Time desc

--13- What is the percentage of downtime impact per product?
select LP.Product,sum (LD.Downtime_in_mins) as Total_Downtime, sum(LP.Total_Minutes) as Total_Production_Time,
    cast(sum(LD.Downtime_in_mins) * 100.0 / sum(LP.Total_Minutes) as decimal (5,2)) as Downtime_Impact_Percentage
from Line_Productivity LP join Line_Downtime LD on LP.Batch = LD.Batch
group by LP.Product
order by Downtime_Impact_Percentage desc

--14- Which operator has the highest downtime?
select top 1 LP.Operator,sum(LD.Downtime_in_mins) as Total_Downtime
from Line_Productivity LP join Line_Downtime LD on LP.Batch = LD.Batch
group by LP.Operator
order by Total_Downtime desc

--15- How many batches does each operator handle?
select operator,count(batch) as total_batches
from line_productivity
group by operator
order by total_batches desc

-- 16- How does each operator’s efficiency change with their downtime?
select lp.Operator, round(avg(abs(lp.Total_Minutes - p.Min_Batch_Time_mins)), 2) as Avg_Efficiency_Deviation,
       count(distinct lp.Batch) as Total_Batches,
   isnull(sum(ld.Downtime_in_mins), 0) as Total_Downtime_Mins,
    cast(isnull(sum(ld.Downtime_in_mins), 0) * 1.0 / count(distinct lp.Batch) as decimal(5,2)) as Avg_Downtime_Per_Batch

from Line_Productivity lp
join Products p on lp.Product = p.Product
left join Line_Downtime ld on lp.Batch = ld.Batch
group by lp.Operator
order by Avg_Efficiency_Deviation 

--17- Is most of the downtime caused by operators or by non-operator?
select ld.operator_error,sum(ld.downtime_in_mins) as total_downtime,
cast(sum(ld.downtime_in_mins) * 100.0 / (select sum(downtime_in_mins) from line_downtime) as decimal(5,2)) as downtime_percentage
from line_downtime ld
group by ld.operator_error

--B- Downtime Causes--

--1.What is the total number of downtime factors?
select count(*) as total_downtime_factors
from downtime_factors

 --2. What is the most time consuming by downtime factor?
select top 1 ld.factor,sum(ld.downtime_in_mins) as total_downtime
from line_downtime ld
group by ld.factor
order by total_downtime desc

--3.What is the most occurred downtime factor?
select top 1 ld.factor,Description,count(*) as occurrences
from line_downtime ld
group by ld.factor ,Description
order by occurrences desc

--4.  How much cumulative downtime did each factor contribute over time?

select lp.Date, ld.Factor, ld.Description, SUM(ld.Downtime_in_mins) as Daily_Downtime, 
        sum(sum(ld.Downtime_in_mins)) over (partition by ld.Factor order by lp.Date) as Cumulative_Total_Downtime

from Line_Productivity lp 
join Line_Downtime ld ON lp.Batch = ld.Batch
group by lp.Date, ld.Factor, ld.Description
order by ld.Factor, lp.Date

--5. Are certain products more affected by specific downtime factors?
select lp.product,ld.factor,sum(ld.downtime_in_mins) as total_downtime
from line_productivity lp join line_downtime ld on lp.batch = ld.batch
group by lp.product, ld.factor
order by lp.product, total_downtime desc

--6. Which operators face more operator-related downtime factors?
select lp.operator,count(ld.factor) as operator_related_downtime_events,sum(ld.downtime_in_mins) as total_operator_related_downtime
from line_productivity lp join line_downtime ld on lp.batch = ld.batch
where ld.operator_error = 'Yes'
group by lp.operator
order by total_operator_related_downtime desc

--7. Which downtime factors occur most often in each shift?
select  lp.shifts,ld.factor, ld.description,
 count(distinct lp.batch) as most_occurrences
from line_productivity lp join line_downtime ld on lp.batch = ld.batch
group by lp.shifts, ld.factor, ld.description
order by lp.shifts, most_occurrences desc




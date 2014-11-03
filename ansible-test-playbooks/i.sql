-- This is a query

create table lala1(a number);
create or replace view lla as select * from lala1;
drop table lala1;
drop view lla;

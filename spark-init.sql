use default;
create table lineitem using parquet location 's3://tpc-h-sf100-parquet/lineitem.parquet/';
create table orders using parquet location 's3://tpc-h-sf100-parquet/orders.parquet/';
create table customer using parquet location 's3://tpc-h-sf100-parquet/customer.parquet/';
create table part using parquet location 's3://tpc-h-sf100-parquet/part.parquet/';
create table supplier using parquet location 's3://tpc-h-sf100-parquet/supplier.parquet/';
create table partsupp using parquet location 's3://tpc-h-sf100-parquet/partsupp.parquet/';
create table nation using parquet location 's3://tpc-h-sf100-parquet/nation.parquet/';
create table region using parquet location 's3://tpc-h-sf100-parquet/region.parquet/';

analyze table lineitem compute statistics for all columns;
analyze table orders compute statistics for all columns;
analyze table customer compute statistics for all columns;
analyze table part compute statistics for all columns;
analyze table supplier compute statistics for all columns;
analyze table partsupp compute statistics for all columns;
analyze table nation compute statistics for all columns;
analyze table region compute statistics for all columns;

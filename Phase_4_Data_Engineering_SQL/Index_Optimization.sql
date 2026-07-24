
-- ==========================================================
-- 4.6 بهینه‌سازی عملکرد و مدیریت ایندکس‌ها
-- بخش اول: ایندکس‌های ترکیبی (Composite Indexes)
-- ==========================================================
USE northwind_project;

-- بررسی ایندکس‌های فعلی جدول Orders
SHOW INDEX FROM Orders;

-- نکته:
-- دستور ADD PRIMARY KEY اجرا نمی‌شود، چون OrderID از قبل کلید اصلی است
-- و اجرای مجدد آن باعث خطای Multiple primary key defined می‌شود

-- برای جلوگیری از خطای Duplicate key name در اجرای مجدد
DROP INDEX idx_orders_employeeid_orderdate ON Orders;
DROP INDEX idx_orders_shipcountry_shipcity_freight ON Orders;
DROP INDEX idx_orders_customerid_orderdate ON Orders;

-- ایندکس ترکیبی برای تحلیل عملکرد کارکنان بر اساس کارمند و تاریخ سفارش
CREATE INDEX idx_orders_employeeid_orderdate
ON Orders (EmployeeID, OrderDate);

-- ایندکس ترکیبی برای تحلیل جغرافیایی سفارش‌ها و هزینه حمل
CREATE INDEX idx_orders_shipcountry_shipcity_freight
ON Orders (ShipCountry, ShipCity, Freight);

-- ایندکس ترکیبی برای بررسی سفارش‌های مشتریان بر اساس تاریخ
CREATE INDEX idx_orders_customerid_orderdate
ON Orders (CustomerID, OrderDate);

-- ----------------------------------------------------------
-- تحلیل استفاده از ایندکس‌ها با EXPLAIN
-- ----------------------------------------------------------

-- استفاده مناسب از ایندکس (EmployeeID, OrderDate)
EXPLAIN
SELECT EmployeeID, OrderDate, COUNT(*)
FROM Orders
WHERE EmployeeID = 5
  AND OrderDate >= '1997-01-01'
GROUP BY EmployeeID, OrderDate;

-- استفاده مناسب از ایندکس (ShipCountry, ShipCity, Freight)
EXPLAIN
SELECT ShipCountry, ShipCity, SUM(Freight)
FROM Orders
WHERE ShipCountry = 'Germany'
GROUP BY ShipCountry, ShipCity;

-- استفاده مناسب از ایندکس (CustomerID, OrderDate)
EXPLAIN
SELECT CustomerID, OrderDate
FROM Orders
WHERE CustomerID = 'ALFKI'
  AND OrderDate >= '1997-01-01';

-- بررسی تاثیر ترتیب ستون‌ها در ایندکس ترکیبی:
-- چون شرط فقط روی OrderDate است و این ستون، ستون اول ایندکس نیست،
-- استفاده بهینه از ایندکس (CustomerID, OrderDate) محدود می‌شود
EXPLAIN
SELECT CustomerID, OrderDate
FROM Orders
WHERE OrderDate >= '1997-01-01';

-- مشاهده نهایی ایندکس‌ها
SHOW INDEX FROM Orders;


-- ==========================================================
-- 4.6 بخش دوم: تحلیل در مقیاس بزرگ (Large-Scale Analysis)
-- ==========================================================

DROP TABLE IF EXISTS Orders_Large_Test;

CREATE TABLE Orders_Large_Test AS
SELECT *
FROM Orders
WHERE 1 = 0;

INSERT INTO Orders_Large_Test
SELECT o.*
FROM Orders o
CROSS JOIN (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
    UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
    UNION ALL SELECT 9
) a
CROSS JOIN (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
    UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
    UNION ALL SELECT 9
) b
CROSS JOIN (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2
    UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6
) c;

SELECT COUNT(*) AS TotalRows
FROM Orders_Large_Test;

SHOW INDEX FROM Orders_Large_Test;

EXPLAIN
SELECT *
FROM Orders_Large_Test
WHERE CustomerID = 'ALFKI';

DROP INDEX IF EXISTS idx_orders_large_customerid ON Orders_Large_Test;

CREATE INDEX idx_orders_large_customerid
ON Orders_Large_Test (CustomerID);

SHOW INDEX FROM Orders_Large_Test;

EXPLAIN
SELECT *
FROM Orders_Large_Test
WHERE CustomerID = 'ALFKI';

EXPLAIN
SELECT *
FROM Orders_Large_Test
WHERE CustomerID = 'ALFKI'
  AND OrderDate >= '1997-01-01';

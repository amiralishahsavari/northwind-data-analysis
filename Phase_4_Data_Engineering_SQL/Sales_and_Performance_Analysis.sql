--  6.1 تحلیل هزینه‌های حمل و توزیع جغرافیایی

-- 6.1.1 شناسایی کشورهای قاره آمریکا
CREATE OR REPLACE VIEW v_distinct_ship_countries AS
SELECT DISTINCT ShipCountry
FROM Orders
ORDER BY ShipCountry;


-- 6.1.3 نمایش سه سفارش با بیشترین هزینه حمل
CREATE OR REPLACE VIEW v_top_3_freight_orders AS
SELECT
    OrderID,
    CustomerID,
    OrderDate,
    Freight,
    ShipCity,
    ShipCountry,
    ShipRegion
FROM Orders
WHERE ShipCountry IN (
    'Argentina',
    'Brazil',
    'Canada',
    'Mexico',
    'USA',
    'Venezuela'
)
ORDER BY Freight DESC
LIMIT 3;


-- 6.1.2 شناسایی سه شهر با بیشترین مجموع هزینه حمل
CREATE OR REPLACE VIEW v_top_3_freight_cities_summary AS
SELECT
    ShipCity,
    ShipCountry,
    ROUND(SUM(Freight), 2) AS TotalFreight
FROM Orders
WHERE ShipCountry IN (
    'Argentina','Brazil','Canada','Mexico','USA','Venezuela'
)
GROUP BY ShipCity, ShipCountry
ORDER BY TotalFreight DESC
LIMIT 3;

-- جزئیات سفارش‌های سه شهر با بیشترین مجموع هزینه حمل
CREATE OR REPLACE VIEW v_top_3_freight_cities_orders AS
SELECT
    OrderID,
    CustomerID,
    OrderDate,
    Freight,
    ShipCity,
    ShipCountry,
    ShipRegion
FROM Orders
WHERE (ShipCity, ShipCountry) IN (
    SELECT ShipCity, ShipCountry
    FROM (
        SELECT
            ShipCity,
            ShipCountry,
            SUM(Freight) AS TotalFreight
        FROM Orders
        WHERE ShipCountry IN (
            'Argentina','Brazil','Canada','Mexico','USA','Venezuela'
        )
        GROUP BY ShipCity, ShipCountry
        ORDER BY TotalFreight DESC
        LIMIT 3
    ) AS TopCities
)
ORDER BY ShipCity, Freight DESC;



-- 6.2 ارزیابی عملکرد کارکنان
-- 6.2.1 شناسایی سه کارمند برتر بر اساس تعداد سفارش‌ها
CREATE OR REPLACE VIEW v_top_3_employees_by_orders AS
SELECT
    e.EmployeeID,
    CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
    COUNT(o.OrderID) AS TotalOrders
FROM Employees e
JOIN Orders o
    ON e.EmployeeID = o.EmployeeID
GROUP BY
    e.EmployeeID,
    e.FirstName,
    e.LastName
ORDER BY TotalOrders DESC
LIMIT 3;


-- 6.2.2 محاسبه شاخص بهره‌وری کارکنان
CREATE OR REPLACE VIEW v_employee_productivity_index AS
SELECT
    e.EmployeeID,
    CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
    COUNT(o.OrderID) AS TotalOrders,
    TIMESTAMPDIFF(YEAR, e.HireDate, (SELECT MAX(OrderDate) FROM Orders)) AS YearsWorked,
    ROUND(
        COUNT(o.OrderID) /
        TIMESTAMPDIFF(YEAR, e.HireDate, (SELECT MAX(OrderDate) FROM Orders)),
        2
    ) AS ProductivityIndex
FROM Employees e
JOIN Orders o
    ON e.EmployeeID = o.EmployeeID
GROUP BY
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.HireDate
ORDER BY ProductivityIndex DESC;


-- 6.2.3 تحلیل بهره‌وری سه کارمند برتر
CREATE OR REPLACE VIEW v_top_3_employees_productivity AS
SELECT
    T.EmployeeID,
    T.EmployeeName,
    T.TotalOrders,
    T.YearsWorked,
    ROUND(T.TotalOrders / T.YearsWorked, 2) AS ProductivityIndex
FROM
(
    SELECT
        e.EmployeeID,
        CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
        COUNT(o.OrderID) AS TotalOrders,
        TIMESTAMPDIFF(YEAR, e.HireDate, (SELECT MAX(OrderDate) FROM Orders)) AS YearsWorked
    FROM Employees e
    JOIN Orders o
        ON e.EmployeeID = o.EmployeeID
    GROUP BY
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.HireDate
    ORDER BY TotalOrders DESC
    LIMIT 3
) AS T;


-- 6.3 ارزیابی سیاست‌های قیمت‌گذاری و الگوهای فروش
-- 6.3.1 تحلیل میانگین قیمت دسته‌بندی‌ها در مقایسه با میانگین کل
CREATE OR REPLACE VIEW v_category_price_analysis AS
SELECT 
    c.CategoryID,
    c.CategoryName,
    ROUND(AVG(p.UnitPrice), 2) AS CategoryAveragePrice,
    (SELECT ROUND(AVG(UnitPrice), 2) FROM Products) AS OverallAveragePrice,
    ROUND(AVG(p.UnitPrice) - (SELECT AVG(UnitPrice) FROM Products), 2) AS DifferenceFromAverage,
    CASE 
        WHEN AVG(p.UnitPrice) > (SELECT AVG(UnitPrice) FROM Products) THEN 'Higher than Average'
        ELSE 'Lower/Equal to Average'
    END AS PriceStatus
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY CategoryAveragePrice DESC;


-- 6.3.2 محاسبه ضریب همبستگی پیرسون بین مقدار خرید و تخفیف
CREATE OR REPLACE VIEW v_pearson_correlation_qty_discount AS
SELECT 
    COUNT(*) AS TotalRecords,
    ROUND(
        (COUNT(*) * SUM(Quantity * Discount) - SUM(Quantity) * SUM(Discount)) / 
        SQRT(
            (COUNT(*) * SUM(Quantity * Quantity) - POW(SUM(Quantity), 2)) * 
            (COUNT(*) * SUM(Discount * Discount) - POW(SUM(Discount), 2))
        ), 
        4
    ) AS Correlation_Quantity_Discount
FROM order_details;

-- 6.3.3 تحلیل وابستگی تخفیف و کارمند مسئول با استفاده از ضریب Eta
CREATE OR REPLACE VIEW v_eta_correlation_employee_discount AS
WITH GlobalStats AS (
    SELECT AVG(Discount) AS GlobalAvg FROM order_details
),
CategoryStats AS (
    SELECT o.EmployeeID, COUNT(od.Discount) AS CategoryCount, AVG(od.Discount) AS CategoryAvg
    FROM order_details od
    JOIN orders o ON od.OrderID = o.OrderID
    GROUP BY o.EmployeeID
),
SumOfSquares AS (
    SELECT
        (SELECT SUM(CategoryCount * POWER(CategoryAvg - GlobalAvg, 2)) FROM CategoryStats CROSS JOIN GlobalStats) AS SSB,
        (SELECT SUM(POWER(od.Discount - g.GlobalAvg, 2)) FROM order_details od CROSS JOIN GlobalStats g) AS SST,
        (SELECT COUNT(*) FROM CategoryStats) AS k,        -- تعداد گروه‌ها
        (SELECT COUNT(*) FROM order_details) AS N
)
SELECT 
    'Employee vs Discount' AS Relationship,
    ROUND(SSB, 4) AS SS_Between,
    ROUND(SST - SSB, 4) AS SS_Within,
    ROUND(SST, 4) AS SS_Total,
    ROUND(SQRT(SSB / SST), 4) AS Eta_Correlation,
    ROUND(
        (SSB/(k-1))
        /
        ((SST-SSB)/(N-k))
    ,4) AS F_Statistic
FROM SumOfSquares;


-- 6.3.4 تحلیل وابستگی تخفیف و کشور مشتری با استفاده از ضریب Eta
CREATE OR REPLACE VIEW v_eta_correlation_country_discount AS
WITH GlobalStats AS (
    SELECT AVG(Discount) AS GlobalAvg FROM order_details
),
CategoryStats AS (
    SELECT o.ShipCountry, COUNT(od.Discount) AS CategoryCount, AVG(od.Discount) AS CategoryAvg
    FROM order_details od
    JOIN orders o ON od.OrderID = o.OrderID
    GROUP BY o.ShipCountry
),
SumOfSquares AS (
    SELECT
        (SELECT SUM(CategoryCount * POWER(CategoryAvg - GlobalAvg, 2)) FROM CategoryStats CROSS JOIN GlobalStats) AS SSB,
        (SELECT SUM(POWER(od.Discount - g.GlobalAvg, 2)) FROM order_details od CROSS JOIN GlobalStats g) AS SST,
        (SELECT COUNT(*) FROM CategoryStats) AS k,        -- تعداد گروه‌ها
        (SELECT COUNT(*) FROM order_details) AS N
)
SELECT 
    'Country vs Discount' AS Relationship,
    ROUND(SSB, 4) AS SS_Between,
    ROUND(SST - SSB, 4) AS SS_Within,
    ROUND(SST, 4) AS SS_Total,
    ROUND(SQRT(SSB / SST), 4) AS Eta_Correlation,
    ROUND(
        (SSB/(k-1))
        /
        ((SST-SSB)/(N-k))
    ,4) AS F_Statistic
FROM SumOfSquares;
 

-- 6.3.5 تحلیل وابستگی تخفیف و شرکت حمل‌ونقل با استفاده از ضریب Eta
CREATE OR REPLACE VIEW v_eta_correlation_shipper_discount AS
WITH GlobalStats AS (
    SELECT AVG(Discount) AS GlobalAvg FROM order_details
),
CategoryStats AS (
    SELECT o.ShipVia, COUNT(od.Discount) AS CategoryCount, AVG(od.Discount) AS CategoryAvg
    FROM order_details od
    JOIN orders o ON od.OrderID = o.OrderID
    GROUP BY o.ShipVia
),
SumOfSquares AS (
    SELECT
        (SELECT SUM(CategoryCount * POWER(CategoryAvg - GlobalAvg, 2)) FROM CategoryStats CROSS JOIN GlobalStats) AS SSB,
        (SELECT SUM(POWER(od.Discount - g.GlobalAvg, 2)) FROM order_details od CROSS JOIN GlobalStats g) AS SST,
        (SELECT COUNT(*) FROM CategoryStats) AS k,        -- تعداد گروه‌ها
        (SELECT COUNT(*) FROM order_details) AS N
)
SELECT 
    'Shipper vs Discount' AS Relationship,
    ROUND(SSB, 4) AS SS_Between,
    ROUND(SST - SSB, 4) AS SS_Within,
    ROUND(SST, 4) AS SS_Total,
    ROUND(SQRT(SSB / SST), 4) AS Eta_Correlation,
    ROUND(
        (SSB/(k-1))
        /
        ((SST-SSB)/(N-k))
    ,4) AS F_Statistic
FROM SumOfSquares;
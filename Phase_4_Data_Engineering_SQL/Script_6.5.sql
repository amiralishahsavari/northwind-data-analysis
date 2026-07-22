-- ۱. ساخت جداول پایه (بدون وابستگی)
CREATE TABLE categories (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(50) NOT NULL,
    Description VARCHAR(255)
);

CREATE TABLE region (
    RegionID INT PRIMARY KEY,
    RegionDescription VARCHAR(50) NOT NULL
);

CREATE TABLE shippers (
    ShipperID INT PRIMARY KEY,
    CompanyName VARCHAR(50) NOT NULL,
    Phone VARCHAR(50)
);

CREATE TABLE suppliers (
    SupplierID INT PRIMARY KEY,
    CompanyName VARCHAR(50) NOT NULL,
    ContactName VARCHAR(50),
    ContactTitle VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(50),
    Region VARCHAR(50),
    PostalCode VARCHAR(50),
    Country VARCHAR(50),
    Phone VARCHAR(50),
    Fax VARCHAR(50),
    HomePage VARCHAR(255)
);

CREATE TABLE customers (
    CustomerID VARCHAR(50) PRIMARY KEY,
    CompanyName VARCHAR(50) NOT NULL,
    ContactName VARCHAR(50),
    ContactTitle VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(50),
    Region VARCHAR(50),
    PostalCode VARCHAR(50),
    Country VARCHAR(50),
    Phone VARCHAR(50),
    Fax VARCHAR(50)
);

-- ۲. ساخت جداول وابسته سطح اول
CREATE TABLE territories (
    TerritoryID INT PRIMARY KEY,
    TerritoryDescription VARCHAR(50) NOT NULL,
    RegionID INT,
    FOREIGN KEY (RegionID) REFERENCES region(RegionID)
);

CREATE TABLE employees (
    EmployeeID INT PRIMARY KEY,
    LastName VARCHAR(50) NOT NULL,
    FirstName VARCHAR(50) NOT NULL,
    Title VARCHAR(50),
    TitleOfCourtesy VARCHAR(50),
    BirthDate DATE,
    HireDate DATE,
    Address VARCHAR(50),
    City VARCHAR(50),
    Region VARCHAR(50),
    PostalCode VARCHAR(50),
    Country VARCHAR(50),
    HomePhone VARCHAR(50),
    Extension INT,
    Notes TEXT,
    ReportsTo INT,
    PhotoPath VARCHAR(255),
    FOREIGN KEY (ReportsTo) REFERENCES employees(EmployeeID)
);

CREATE TABLE products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(50) NOT NULL,
    SupplierID INT,
    CategoryID INT,
    QuantityPerUnit VARCHAR(50),
    UnitPrice DOUBLE,
    UnitsInStock INT,
    UnitsOnOrder INT,
    ReorderLevel INT,
    Discontinued INT,
    FOREIGN KEY (SupplierID) REFERENCES suppliers(SupplierID),
    FOREIGN KEY (CategoryID) REFERENCES categories(CategoryID)
);

-- ۳. ساخت جداول وابسته سطح دوم و سوم
CREATE TABLE employeeterritories (
    EmployeeID INT,
    TerritoryID INT,
    PRIMARY KEY (EmployeeID, TerritoryID),
    FOREIGN KEY (EmployeeID) REFERENCES employees(EmployeeID),
    FOREIGN KEY (TerritoryID) REFERENCES territories(TerritoryID)
);

CREATE TABLE orders (
    OrderID INT PRIMARY KEY,
    CustomerID VARCHAR(50),
    EmployeeID INT,
    OrderDate DATE,
    RequiredDate DATE,
    ShippedDate DATE,
    ShipVia INT,
    Freight DOUBLE,
    ShipName VARCHAR(50),
    ShipAddress VARCHAR(50),
    ShipCity VARCHAR(50),
    ShipRegion VARCHAR(50),
    ShipPostalCode VARCHAR(50),
    ShipCountry VARCHAR(50),
    FOREIGN KEY (CustomerID) REFERENCES customers(CustomerID),
    FOREIGN KEY (EmployeeID) REFERENCES employees(EmployeeID),
    FOREIGN KEY (ShipVia) REFERENCES shippers(ShipperID)
);

CREATE TABLE order_details (
    OrderID INT,
    ProductID INT,
    UnitPrice DOUBLE,
    Quantity INT,
    Discount DOUBLE,
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID) REFERENCES orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES products(ProductID)
);

SET FOREIGN_KEY_CHECKS = 0;
SET FOREIGN_KEY_CHECKS = 1;

ALTER TABLE employees DROP FOREIGN KEY employees_ibfk_1;
ALTER TABLE employees ADD CONSTRAINT employees_ibfk_1 FOREIGN KEY (ReportsTo) REFERENCES employees(EmployeeID);


-- ایجاد نمای منطقی برای جزئیات سفارشات و محاسبه فروش خالص
CREATE OR REPLACE VIEW SalesOrderDetailsView AS
SELECT 
    o.OrderID,
    o.OrderDate,
    o.ShipCountry,
    c.CategoryName,
    p.ProductName,
    od.UnitPrice,
    od.Quantity,
    od.Discount,
    ROUND((od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS NetSales
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
JOIN categories c ON p.CategoryID = c.CategoryID;

SELECT * FROM SalesOrderDetailsView LIMIT 10;

CREATE TEMPORARY TABLE HighSalesCountries AS
SELECT 
    ShipCountry,
    SUM(NetSales) AS TotalSales
FROM SalesOrderDetailsView
GROUP BY ShipCountry
HAVING SUM(NetSales) > (
    SELECT AVG(TotalSales)
    FROM (
        SELECT 
            ShipCountry,
            SUM(NetSales) AS TotalSales
        FROM SalesOrderDetailsView
        GROUP BY ShipCountry
    ) AS CountryAvg
);

CREATE TEMPORARY TABLE PopularCategories AS
SELECT
    s.ShipCountry,
    s.CategoryName,
    SUM(s.NetSales) AS CategorySales
FROM SalesOrderDetailsView s
JOIN HighSalesCountries h
    ON s.ShipCountry = h.ShipCountry
GROUP BY 
    s.ShipCountry,
    s.CategoryName;


SELECT
    ShipCountry,
    CategoryName,
    CategorySales
FROM (
    SELECT
        ShipCountry,
        CategoryName,
        CategorySales,
        ROW_NUMBER() OVER (
            PARTITION BY ShipCountry
            ORDER BY CategorySales DESC
        ) AS rn
    FROM PopularCategories
) AS RankedCategories
WHERE rn = 1
ORDER BY CategorySales DESC;

-- تست ردیف اول برای اطمینان از صحت کد
SELECT AVG(TotalSales)
FROM (
    SELECT 
        ShipCountry,
        SUM(NetSales) AS TotalSales
    FROM SalesOrderDetailsView
    GROUP BY ShipCountry
) x;
SELECT 
    ShipCountry,
    SUM(NetSales)
FROM SalesOrderDetailsView
WHERE ShipCountry='USA'
GROUP BY ShipCountry;
SELECT
    CategoryName,
    SUM(NetSales) AS Sales
FROM SalesOrderDetailsView
WHERE ShipCountry='USA'
GROUP BY CategoryName
ORDER BY Sales DESC;

-- Create the Customers table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100),
    signup_date DATE,
    region VARCHAR(50)
);

-- Create the Orders table
CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    order_status VARCHAR(20),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Create the Order_Items table
CREATE TABLE Order_Items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    price DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)
);

-- Create the Products table
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50)
);

-- Insert data into Customers
INSERT INTO Customers (customer_id, name, signup_date, region)
VALUES 
(1, 'John Doe', '2023-01-10', 'North'),
(2, 'Jane Smith', '2023-02-15', 'South'),
(3, 'Alice Johnson', '2023-03-05', 'East'),
(4, 'Bob Brown', '2023-04-20', 'West');

-- Insert data into Orders
INSERT INTO Orders (order_id, customer_id, order_date, order_status)
VALUES 
(101, 1, '2023-05-01', 'completed'),
(102, 2, '2023-06-10', 'completed'),
(103, 3, '2023-07-15', 'canceled'),
(104, 1, '2023-08-01', 'completed'),
(105, 4, '2023-08-20', 'completed');

-- Insert data into Order_Items
INSERT INTO Order_Items (order_item_id, order_id, product_id, quantity, price)
VALUES 
(1001, 101, 201, 2, 19.99),
(1002, 101, 202, 1, 9.99),
(1003, 102, 201, 3, 19.99),
(1004, 104, 203, 1, 29.99),
(1005, 105, 202, 4, 9.99);

-- Insert data into Products
INSERT INTO Products (product_id, product_name, category)
VALUES 
(201, 'Wireless Mouse', 'Electronics'),
(202, 'Keyboard', 'Electronics'),
(203, 'Webcam', 'Electronics'),
(204, 'Monitor', 'Electronics');

-- Customer Lifetime Value (CLV) Calculation
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.name,
        SUM(oi.quantity * oi.price) AS total_revenue
    FROM 
        Customers c
    JOIN 
        Orders o ON c.customer_id = o.customer_id
    JOIN 
        Order_Items oi ON o.order_id = oi.order_id
    WHERE 
        o.order_status = 'completed'
    GROUP BY 
        c.customer_id, c.name
)
SELECT 
    customer_id,
    name,
    total_revenue,
    NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile
FROM 
    customer_revenue;

-- RFM Analysis (Recency, Frequency, Monetary)
WITH rfm AS (
    SELECT 
        c.customer_id,
        MAX(o.order_date) AS last_order_date,
        COUNT(o.order_id) AS frequency,
        SUM(oi.quantity * oi.price) AS monetary
    FROM 
        Customers c
    JOIN 
        Orders o ON c.customer_id = o.customer_id
    JOIN 
        Order_Items oi ON o.order_id = oi.order_id
    WHERE 
        o.order_status = 'completed'
    GROUP BY 
        c.customer_id
)
SELECT 
    customer_id,
    DATEDIFF(DAY, last_order_date, GETDATE()) AS recency,
    frequency,
    monetary,
    ROW_NUMBER() OVER (ORDER BY recency, frequency DESC, monetary DESC) AS rfm_rank
FROM 
    rfm;

-- Product Affinity Analysis
WITH product_pairs AS (
    SELECT 
        oi1.product_id AS product_a,
        oi2.product_id AS product_b,
        COUNT(*) AS times_bought_together
    FROM 
        Order_Items oi1
    JOIN 
        Order_Items oi2 ON oi1.order_id = oi2.order_id
    WHERE 
        oi1.product_id < oi2.product_id
    GROUP BY 
        oi1.product_id, oi2.product_id
)
SELECT 
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    times_bought_together,
    RANK() OVER (ORDER BY times_bought_together DESC) AS rank
FROM 
    product_pairs pp
JOIN 
    Products p1 ON pp.product_a = p1.product_id
JOIN 
    Products p2 ON pp.product_b = p2.product_id
WHERE 
    times_bought_together > 5;

-- Customer Churn Prediction
WITH customer_activity AS (
    SELECT 
        c.customer_id,
        MAX(o.order_date) AS last_purchase_date,
        AVG(DATEDIFF(DAY, LAG(o.order_date) OVER (PARTITION BY c.customer_id ORDER BY o.order_date), o.order_date)) AS avg_purchase_interval
    FROM 
        Customers c
    JOIN 
        Orders o ON c.customer_id = o.customer_id
    WHERE 
        o.order_status = 'completed'
    GROUP BY 
        c.customer_id
)
SELECT 
    customer_id,
    last_purchase_date,
    avg_purchase_interval,
    DATEDIFF(DAY, last_purchase_date, GETDATE()) AS days_since_last_purchase,
    CASE 
        WHEN DATEDIFF(DAY, last_purchase_date, GETDATE()) > avg_purchase_interval * 2 THEN 'At Risk'
        ELSE 'Active'
    END AS churn_risk
FROM 
    customer_activity;

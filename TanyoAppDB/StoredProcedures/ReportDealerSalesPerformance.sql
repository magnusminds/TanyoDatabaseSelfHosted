-- =====================================================================
-- Report   : Dealer Sales Performance Report (TAN-4418)
-- Purpose  : Returns one long-format row per Dealer per period bucket
--            having qualifying sales inside the range, plus one sentinel
--            row (BucketIndex = 0) per qualifying Dealer with zero sales
--            (only possible for Lesser Than / Lesser Than Equal To).
-- Buckets  : @PeriodType 1 = Monthly (calendar months)
--                     2 = Quarterly (Indian FY: Apr-Jun, Jul-Sep, Oct-Dec, Jan-Mar)
--                     3 = Yearly (Indian FY: Apr 1 - Mar 31)
-- Operators: @AmountOperator 1 = >=, 2 = >, 3 = <, 4 = <=, 5 = =
--            applied to the Dealer's TOTAL sales across the whole range.
-- Sales    : Orders with Status IN (4 Completed, 5 Delivered), not archived;
--            order date = COALESCE(ApprovedDate, CreatedDate).
-- NOTE     : BucketLabel is informational only (DATENAME is server-language
--            dependent); the application derives authoritative labels.
-- =====================================================================
CREATE PROCEDURE [dbo].[ReportDealerSalesPerformance]
        @TenantId INT
        ,@FromDate DATE
        ,@ToDate DATE
        ,@PeriodType INT
        ,@AmountOperator INT
        ,@MinAmount DECIMAL(18, 2)
        ,@SalesmanId BIGINT = NULL
        ,@LocationId BIGINT = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        ------------------------------------------------------------------
        -- 1. Period bucket calendar
        ------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#PeriodBuckets') IS NOT NULL
            DROP TABLE #PeriodBuckets;

        CREATE TABLE #PeriodBuckets
        (
            BucketIndex INT IDENTITY(1, 1)
            ,BucketStart DATE NOT NULL
            ,BucketEnd DATE NOT NULL
            ,BucketLabel VARCHAR(60) NOT NULL
        );

        IF @PeriodType = 1 -- Monthly: calendar months
        BEGIN
            DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1);
            WHILE @MonthStart <= @ToDate
            BEGIN
                INSERT INTO #PeriodBuckets (BucketStart, BucketEnd, BucketLabel)
                VALUES (@MonthStart, EOMONTH(@MonthStart),
                        LEFT(DATENAME(MONTH, @MonthStart), 3) + ' ' + CAST(YEAR(@MonthStart) AS VARCHAR(4)));
                SET @MonthStart = DATEADD(MONTH, 1, @MonthStart);
            END
        END
        ELSE IF @PeriodType = 2 -- Quarterly: Indian FY quarters
        BEGIN
            DECLARE @QuarterStart DATE;
            DECLARE @QM INT;
            DECLARE @QLabel VARCHAR(60);
            SET @QM = MONTH(@FromDate);
            IF @QM BETWEEN 4 AND 6
                SET @QuarterStart = DATEFROMPARTS(YEAR(@FromDate), 4, 1);
            ELSE IF @QM BETWEEN 7 AND 9
                SET @QuarterStart = DATEFROMPARTS(YEAR(@FromDate), 7, 1);
            ELSE IF @QM BETWEEN 10 AND 12
                SET @QuarterStart = DATEFROMPARTS(YEAR(@FromDate), 10, 1);
            ELSE
                SET @QuarterStart = DATEFROMPARTS(YEAR(@FromDate), 1, 1);

            WHILE @QuarterStart <= @ToDate
            BEGIN
                SET @QM = MONTH(@QuarterStart);
                IF @QM = 4
                    SET @QLabel = 'Q1 FY ' + CAST(YEAR(@QuarterStart) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST((YEAR(@QuarterStart) + 1) % 100 AS VARCHAR(2)), 2);
                ELSE IF @QM = 7
                    SET @QLabel = 'Q2 FY ' + CAST(YEAR(@QuarterStart) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST((YEAR(@QuarterStart) + 1) % 100 AS VARCHAR(2)), 2);
                ELSE IF @QM = 10
                    SET @QLabel = 'Q3 FY ' + CAST(YEAR(@QuarterStart) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST((YEAR(@QuarterStart) + 1) % 100 AS VARCHAR(2)), 2);
                ELSE
                    SET @QLabel = 'Q4 FY ' + CAST(YEAR(@QuarterStart) - 1 AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(YEAR(@QuarterStart) % 100 AS VARCHAR(2)), 2);

                INSERT INTO #PeriodBuckets (BucketStart, BucketEnd, BucketLabel)
                VALUES (@QuarterStart, DATEADD(DAY, -1, DATEADD(MONTH, 3, @QuarterStart)), @QLabel);
                SET @QuarterStart = DATEADD(MONTH, 3, @QuarterStart);
            END
        END
        ELSE IF @PeriodType = 3 -- Yearly: Indian FY (Apr 1 - Mar 31)
        BEGIN
            DECLARE @FyStartYear INT = CASE WHEN MONTH(@FromDate) >= 4 THEN YEAR(@FromDate) ELSE YEAR(@FromDate) - 1 END;
            WHILE DATEFROMPARTS(@FyStartYear, 4, 1) <= @ToDate
            BEGIN
                INSERT INTO #PeriodBuckets (BucketStart, BucketEnd, BucketLabel)
                VALUES (DATEFROMPARTS(@FyStartYear, 4, 1), DATEFROMPARTS(@FyStartYear + 1, 3, 31),
                        'FY ' + CAST(@FyStartYear AS VARCHAR(4)) + '-' + RIGHT('0' + CAST((@FyStartYear + 1) % 100 AS VARCHAR(2)), 2));
                SET @FyStartYear = @FyStartYear + 1;
            END
        END

        ------------------------------------------------------------------
        -- 2. Qualifying customers: full roster LEFT JOINed with in-range
        --    sales; the amount operator applies to the coalesced total
        ------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#QualifyingCustomers') IS NOT NULL
            DROP TABLE #QualifyingCustomers;

        SELECT
                c.CustomerId
                ,LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) AS CustomerName
                ,c.PhoneNumber
                ,ISNULL(ct.Name, '') AS CustomerTypeName
                ,ISNULL(SUM(o.TotalAmount), 0) AS RangeTotalSales
                ,COUNT(o.OrderId) AS RangeTotalOrders
        INTO #QualifyingCustomers
        FROM Customers c
        LEFT JOIN Orders o
                ON o.CustomerID = c.CustomerId
                AND o.TenantId = @TenantId
                AND o.IsArchive = 0
                AND o.Status IN (4, 5)  -- Completed, Delivered
                AND CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) >= @FromDate
                AND CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) < DATEADD(DAY, 1, @ToDate)
                AND (@SalesmanId IS NULL OR o.SalesmanId = @SalesmanId)
                AND (@LocationId IS NULL OR o.LocationId = @LocationId)
        LEFT JOIN CustomerTypes ct
                ON ct.CustomerTypeId = c.CustomerTypeId
        WHERE c.TenantId = @TenantId
                AND c.IsDeleted = 0
                AND c.CustomerTypeId = 4  -- CustomerTypeEnum.Dealer
        GROUP BY c.CustomerId, c.FirstName, c.LastName, c.PhoneNumber, ct.Name;

        DELETE FROM #QualifyingCustomers
        WHERE NOT (
                    (@AmountOperator = 1 AND RangeTotalSales >= @MinAmount)
                 OR (@AmountOperator = 2 AND RangeTotalSales > @MinAmount)
                 OR (@AmountOperator = 3 AND RangeTotalSales < @MinAmount)
                 OR (@AmountOperator = 4 AND RangeTotalSales <= @MinAmount)
                 OR (@AmountOperator = 5 AND RangeTotalSales = @MinAmount)
                );

        ------------------------------------------------------------------
        -- 3. Result: bucket rows for customers having sales in the bucket
        --    + one sentinel all-zero row per qualifying customer without
        --    any sales in the range (BucketIndex = 0)
        ------------------------------------------------------------------
        SELECT
                q.CustomerId
                ,q.CustomerName
                ,q.PhoneNumber
                ,q.CustomerTypeName
                ,b.BucketIndex
                ,b.BucketLabel
                ,ISNULL(SUM(o.TotalAmount), 0) AS BucketAmount
                ,COUNT(o.OrderId) AS BucketOrderCount
                ,q.RangeTotalSales
                ,q.RangeTotalOrders
        FROM #QualifyingCustomers q
        INNER JOIN Orders o
                ON o.CustomerID = q.CustomerId
                AND o.TenantId = @TenantId
                AND o.IsArchive = 0
                AND o.Status IN (4, 5)
                AND CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) >= @FromDate
                AND CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) < DATEADD(DAY, 1, @ToDate)
                AND (@SalesmanId IS NULL OR o.SalesmanId = @SalesmanId)
                AND (@LocationId IS NULL OR o.LocationId = @LocationId)
        INNER JOIN #PeriodBuckets b
                ON CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) >= b.BucketStart
                AND CAST(COALESCE(o.ApprovedDate, o.CreatedDate) AS DATE) <= b.BucketEnd
        GROUP BY q.CustomerId, q.CustomerName, q.PhoneNumber, q.CustomerTypeName, b.BucketIndex, b.BucketLabel, q.RangeTotalSales, q.RangeTotalOrders

        UNION ALL

        -- Sentinel: one all-zero row per qualifying customer with no sales in range
        SELECT
                CustomerId
                ,CustomerName
                ,PhoneNumber
                ,CustomerTypeName
                ,0 AS BucketIndex
                ,CAST(NULL AS VARCHAR(60)) AS BucketLabel
                ,0 AS BucketAmount
                ,0 AS BucketOrderCount
                ,RangeTotalSales
                ,RangeTotalOrders
        FROM #QualifyingCustomers
        WHERE RangeTotalOrders = 0

        ORDER BY CustomerId, BucketIndex;
    END TRY
BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
END CATCH
END;

GO


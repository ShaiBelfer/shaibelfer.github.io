-- Delete column1
ALTER TABLE taxi_trips_2023_total
DROP COLUMN column1;

--Delete entries where the Taxi ID, Trip Total, Trip End Timestamp, Trip Miles or Trip Seconds are Null
DELETE FROM taxi_trips_2023_total
WHERE Taxi_ID IS NULL
   OR Trip_Total IS NULL
   OR Trip_End_Timestamp IS NULL
   OR Trip_Miles IS NULL
   OR Trip_Seconds IS NULL;

--Remove commas from the Trip Seconds column so it will clearly read as an INT
UPDATE taxi_trips_2023_total
SET "Trip_Seconds" = REPLACE("Trip_Seconds", ',', '')
WHERE "Trip_Seconds" LIKE '%,%';

--Make companies with multiple listings uniform
UPDATE taxi_trips_2023_total
SET company = 'Taxicab Insurance Agency, LLC'
WHERE company = 'Taxicab Insurance Agency Llc';

UPDATE taxi_trips_2023_total
SET company = 'Taxi Affiliation Services'
WHERE company = 'Taxi Affiliation Services Llc - Yell';

UPDATE taxi_trips_2023_total
SET company = 'Choice Taxi Association'
WHERE company = 'Choice Taxi Association Inc';

-- Delete rows from taxi_trips_2023_total where Trip total is 0 and Payment time is not "no charge"
DELETE FROM taxi_trips_2023_total
WHERE 
    Trip_Total = 0 
    AND Payment_Type <> 'No Charge';

	-- Create the bridge table
CREATE TABLE driver_company_bridge (
    Taxi_ID NVARCHAR(150),
    Company NVARCHAR(50),
    PRIMARY KEY (Taxi_ID, Company)  -- Composite primary key to ensure uniqueness
);

-- Populate the bridge table with the relevant data
INSERT INTO driver_company_bridge (Taxi_ID, Company)
SELECT DISTINCT 
    d.Taxi_ID,
    t.Company
FROM 
    drivers d
JOIN 
    taxi_trips_2023_total t ON d.Taxi_ID = t.Taxi_ID
ORDER BY 
taxi_id ASC;

--Creation of Retention Rate table
WITH MonthlyTaxiData AS (
    SELECT 
        Company,
        DATEPART(MONTH, Trip_Start_Timestamp) AS Month,
        Taxi_ID,
        MIN(Trip_Start_Timestamp) OVER (PARTITION BY Taxi_ID) AS FirstTrip
    FROM 
        test2.[dbo].[taxi_trips_2023_total]
    WHERE 
        DATEPART(YEAR, Trip_Start_Timestamp) = 2023
),
UniqueTaxisPerMonth AS (
    SELECT 
        Company,
        Month,
        COUNT(DISTINCT Taxi_ID) AS A,
        LAG(COUNT(DISTINCT Taxi_ID), 1, 0) OVER (PARTITION BY Company ORDER BY Month) AS B
    FROM 
        MonthlyTaxiData
    GROUP BY 
        Company, Month
),
NewTaxisPerMonth AS (
    SELECT 
        Company,
        DATEPART(MONTH, FirstTrip) AS Month,
        COUNT(DISTINCT Taxi_ID) AS C
    FROM 
        MonthlyTaxiData
    WHERE 
        DATEPART(YEAR, FirstTrip) = 2023
    GROUP BY 
        Company, DATEPART(MONTH, FirstTrip)
)
SELECT 
    ut.Company,
    ut.Month,
    ut.A,
    ut.B,
    ISNULL(nt.C, 0) AS C,
    CAST((ut.A - ISNULL(nt.C, 0)) AS FLOAT) / NULLIF(ut.B, 0) AS Result
INTO 
    RetentionRate
FROM 
    UniqueTaxisPerMonth ut
LEFT JOIN 
    NewTaxisPerMonth nt ON ut.Company = nt.Company AND ut.Month = nt.Month;


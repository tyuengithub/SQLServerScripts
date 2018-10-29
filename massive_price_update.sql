USE dBuilder_Master
GO

DECLARE @PriceIncreasePercentage DECIMAL (10,2)  = 0.25 -- INCREASE BY 25%
	, @CurrentPriceListID INT = 6073

-- Adding 1 indicate 100% + increase % to optimize query
SELECT @PriceIncreasePercentage = 1 + @PriceIncreasePercentage


-- adding of 0.5 to do the rounding to the nearest who digit
-- the subtraction is to maintain the same decimal ending
SELECT TOP 5000 CurrentPrice, RegularPrice
	, CASE 
		WHEN RIGHT (CurrentPrice, 2)  = '99' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.01
		WHEN RIGHT (CurrentPrice, 2)  = '98' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.02
		WHEN RIGHT (CurrentPrice, 2)  = '95' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.05
		ELSE CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2))
		END AS NewCurrentPrice
	, CASE 
		WHEN RIGHT (RegularPrice, 2)  = '99' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.01
		WHEN RIGHT (RegularPrice, 2)  = '98' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.02
		WHEN RIGHT (RegularPrice, 2)  = '95' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.05
		ELSE CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2))
		END AS NewRegularPrice
FROM tblItemPrice
WHERE CurrentPriceListID IN (@CurrentPriceListID )

/*
-- to update the price

UPDATE 	ip
SET CurrentPrice = CASE 
		WHEN RIGHT (CurrentPrice, 2)  = '99' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.01
		WHEN RIGHT (CurrentPrice, 2)  = '98' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.02
		WHEN RIGHT (CurrentPrice, 2)  = '95' THEN CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.05
		ELSE CAST(CAST((CurrentPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2))
	, RegularPrice = CASE 
		WHEN RIGHT (RegularPrice, 2)  = '99' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.01
		WHEN RIGHT (RegularPrice, 2)  = '98' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.02
		WHEN RIGHT (RegularPrice, 2)  = '95' THEN CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2)) - 0.05
		ELSE CAST(CAST((RegularPrice * @PriceIncreasePercentage) + 0.5 AS INT) AS decimal(10, 2))
		END AS NewRegularPrice
FROM tblItemPrice ip
WHERE CurrentPriceListID IN (@CurrentPriceListID )


*/
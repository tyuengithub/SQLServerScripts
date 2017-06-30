Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[spsSalesForPIRByDateRangeWOMerchant] (
    @StartDate DATETIME,
    @EndDate DATETIME,
    @CustomerZoneBits VARCHAR(200) = '1,2,3,4,5,7,9,10,12,13,14,15,16,100',
    @WeeksBack SMALLINT = 8,
    @ExcludeMerchants BIT = 1,
    @OnlyCSReps BIT = 0,
	@LanguageBits INT = 0,
	@OnlyPayPalOrders BIT = 0,
	@OnlyCustomFramedOrders BIT = 0, 
	@OrderSource VARCHAR(1000) = '',
	--@OrderSource VARCHAR(1000) = 'allposters.co.jp,allposters.com.ar,allposters.com.au,allposters.com.br,allposters.com.mx,allposters.pl,allposters.pt'
	@AdjustmentMethod SMALLINT = 0 --3 -For both After and Before Hours, 1 - Always go before Hours , 2 - Just after Hours. Anything 1, 1, 3 will be no Adjustments.
)
AS
BEGIN
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @ALLZones TABLE (CustomerZoneID INT)
DECLARE @AllLanguages TABLE (LanguageID INT)


/*
    Author: Mani
    Created on : 12/01/2006
    Purpose : Due to recent increase in Production Incidents, I thought we could reduce number of hours spent on analyzing the revenue impact.
    Logic : The logic is simple. Based on the day of week and time duration, the report goes back to N number of weeks for the same day of week 
            and for the time duration gets the number of orders and order amount and finds the N+1th Forecast total (XL Forecast funciton). 
*/


	INSERT INTO @ALLZones (CustomerZoneID) 
	SELECT CZ.CustomerZoneID
	FROM tlkCustomerZone CZ
	INNER JOIN dbo.SplitString(@CustomerZoneBits, ',') S ON CAST(S.String AS INT) = CZ.CustomerZoneID
	
	--WHERE POWER(2, CZ.CustomerZoneID-1) & @CustomerZoneBits = POWER(2, CZ.CustomerZoneID-1)
	--AND CustomerZoneID < 100
	
	INSERT INTO @AllLanguages (LanguageID)
	SELECT
		LanguageID
	FROM
		tlkLanguage
	WHERE
		POWER(2, LanguageID-1) & @LanguageBits = POWER(2, LanguageID-1)
	
	IF (dbo.TruncTime_DateTime(@StartDate) <> dbo.TruncTime_DateTime(@EndDate) )
	BEGIN
		PRINT 'Error..StartDate and EndDate should be on the same date'
		RETURN -1
	END

    CREATE TABLE #AllCSRepOrders (OrderID INT)
    CREATE TABLE #AllARTCSAccountNumbers (RFAccountNumber BIGINT)
    CREATE TABLE #AllAPCCSAIDs (AID INT)
	CREATE TABLE #AllPayPalOrders (OrderID INT)
	CREATE TABLE #AllCustomFramedOrders (OrderID INT)
	CREATE TABLE #AllOrderSource (OrderSourceID INT, OrderSource VARCHAR(100))

    CREATE CLUSTERED INDEX CDX_#AllCSRepOrders ON #AllCSRepOrders (OrderID)
	CREATE CLUSTERED INDEX CDX_#AllPayPalOrders ON #AllPayPalOrders (OrderID)

	INSERT INTO #AllOrderSource (OrderSourceID, OrderSource)
	SELECT OrderSourceID, OrderSource
	FROM 
		tlkOrderSource
	WHERE
		@OrderSource = ''
	OR  OrderSource IN (SELECT String FROM dbo.SplitString(@OrderSource, ','))

	CREATE INDEX IX_#AllOrderSource ON #AllOrderSource (OrderSource) 
	--SELECT * FROM #AllOrderSource
	DECLARE 
		@DT DATETIME, 
		@HDT DATETIME, 
		@EDT DATETIME,
		@ForecastDate DATETIME

	SET  @DT = @StartDate
	SET @HDT = DATEADD(WW, -@WeeksBack, @DT)
	SET @EDT = DATEADD(D, 1, @DT)

	SET @ForecastDate = dbo.TruncTime_DateTime(@StartDate)

    IF @OnlyCSReps = 1
    BEGIN

        INSERT INTO #AllARTCSAccountNumbers (RFAccountNumber) EXEC SRVDAFF.dAff.dbo.spsARTCSRepAccountNumbers
        INSERT INTO #AllAPCCSAIDs (AID) EXEC SRVDAFF.dAff.dbo.spsAPCCSRepAIDs

        INSERT INTO #AllCSRepOrders (OrderID)
        SELECT O.OrderID
        FROM 
            tblOrderReferrerART OA (NOLOCK) 
            INNER JOIN tblOrder O (NOLOCK) ON OA.OrderID = O.OrderID
        WHERE OA.RFAccountNumber IN (SELECT RFAccountNumber FROM #AllARTCSAccountNumbers)
    	AND O.DateCreated >= @HDT
    	AND O.DateCreated < @EDT
    	AND DATEPART(DW, O.DateCreated) = DATEPART(DW, @DT)
    	AND O.CustomerZoneID IN (SELECT CustomerZoneID FROM @ALLZones)
    	AND (@ExcludeMerchants = 0 OR (O.MerchantOrderID IS NULL OR CHARINDEX('amazon', O.MerchantName) = 0))
		AND CHARINDEX('Refund', O.OrderType) = 0
		AND CHARINDEX('Reship', O.OrderType) = 0
		AND CHARINDEX('Test', O.OrderType) = 0

        INSERT INTO #AllCSRepOrders (OrderID)
        SELECT O.OrderID FROM tblOrder O (NOLOCK) WHERE O.AID IN (SELECT AID FROM #AllAPCCSAIDs)
    	AND	O.DateCreated >= @HDT
    	AND O.DateCreated < @EDT
    	AND DATEPART(DW, O.DateCreated) = DATEPART(DW, @DT)
    	AND O.CustomerZoneID IN (SELECT CustomerZoneID FROM @ALLZones)
    	AND (@ExcludeMerchants = 0 OR (O.MerchantOrderID IS NULL OR CHARINDEX('amazon', O.MerchantName) = 0))
		AND CHARINDEX('Refund', O.OrderType) = 0
		AND CHARINDEX('Reship', O.OrderType) = 0
		AND CHARINDEX('Test', O.OrderType) = 0

    END

	IF @OnlyPayPalOrders = 1
	BEGIN

        INSERT INTO #AllPayPalOrders (OrderID)
		SELECT
			DISTINCT tblOrder.OrderID
		FROM
			tblOrder (NOLOCK)
			INNER JOIN (
				SELECT 
					OrderID,
					MAX(OrderPaymentID) AS OrderPaymentID
				FROM
					dbo.tblOrderPayment (NOLOCK)
				WHERE
					PaymentTypeID <> 6
				GROUP BY OrderID
			) LastPayment ON LastPayment.OrderID = tblOrder.OrderID
			INNER JOIN tblOrderPayment ON tblOrderPayment.OrderPaymentID = LastPayment.OrderPaymentID
			INNER JOIN tlkPaymentType ON tlkPaymentType.PaymentTypeID = tblOrderPayment.PaymentTypeID
		WHERE 
			COALESCE(tlkPaymentType.Description, '') = 'Check' 
		AND COALESCE(tblOrderPayment.AccountType, '') = 'PayPal' 
    	AND tblOrder.DateCreated >= @HDT
    	AND tblOrder.DateCreated < @EDT
    	AND DATEPART(DW, tblOrder.DateCreated) = DATEPART(DW, @DT)
    	AND tblOrder.CustomerZoneID IN (SELECT CustomerZoneID FROM @ALLZones)
    	AND (@ExcludeMerchants = 0 OR (tblOrder.MerchantOrderID IS NULL OR CHARINDEX('amazon', tblOrder.MerchantName) = 0))
		AND CHARINDEX('Refund', tblOrder.OrderType) = 0
		AND CHARINDEX('Reship', tblOrder.OrderType) = 0
		AND CHARINDEX('Test', tblOrder.OrderType) = 0

	END

	IF @OnlyCustomFramedOrders = 1
	BEGIN
		INSERT INTO #AllCustomFramedOrders (OrderID)
		SELECT tblOrder.OrderID
		FROM tblOrder
		WHERE 
			tblOrder.DateCreated >= @HDT
    	AND tblOrder.DateCreated < @EDT
    	AND DATEPART(DW, tblOrder.DateCreated) = DATEPART(DW, @DT)
    	AND tblOrder.CustomerZoneID IN (SELECT CustomerZoneID FROM @ALLZones)
    	AND (@ExcludeMerchants = 0 OR (tblOrder.MerchantOrderID IS NULL OR CHARINDEX('amazon', tblOrder.MerchantName) = 0))
		AND CHARINDEX('Refund', tblOrder.OrderType) = 0
		AND CHARINDEX('Reship', tblOrder.OrderType) = 0
		AND CHARINDEX('Test', tblOrder.OrderType) = 0
		AND EXISTS (SELECT 1 FROM tblOrderItem INNER JOIN tblOrderItemCustomization Z ON Z.OrderItemID = tblOrderItem.OrderItemID
					WHERE Z.ServiceType = 'Frame' AND tblOrderItem.OrderID = tblOrder.OrderID)
	END 

	SELECT	
		dbo.TruncTime_DateTime(O.DateCreated) OrderDate,	
		DATEPART(DW, O.DateCreated) [WeekDay],
		DATEPART(HH, O.DateCreated) OrderHour,
		CONVERT(INT, ((DATEPART(MI, O.DateCreated) / 60.0) * 100) / 25) + 1 OrderTimeQtr,	SUM(COALESCE(O.ExchangeRateOnCreateDate, 1) * O.Total ) Total,	
		COUNT(1) [Count]
	INTO #T
	FROM
		tblOrder O (NOLOCK)
        LEFT JOIN tblCustomer C (NOLOCK) 
			INNER JOIN tblAPCTestLogin TL (NOLOCK) ON TL.EMail = C.EMail 
        ON O.CustomerID = C.CustomerID
        LEFT JOIN #AllCSRepOrders AP ON AP.OrderID = O.OrderID
		LEFT JOIN #AllPayPalOrders APO ON APO.OrderID = O.OrderID
	WHERE	
		O.DateCreated >= dbo.TruncTime_DateTime(@HDT)
	AND O.DateCreated < @EDT
	AND DATEPART(DW, O.DateCreated) = DATEPART(DW, @DT)
	AND O.CustomerZoneID IN (SELECT CustomerZoneID FROM @ALLZones)
  	AND (@ExcludeMerchants = 0 OR (O.MerchantOrderID IS NULL OR CHARINDEX('amazon', O.MerchantName) = 0))
    AND C.CustomerID IS NULL
    AND (@OnlyCSReps = 0 OR AP.OrderID IS NOT NULL)
	AND (@LanguageBits = 0 OR O.LanguageID IN (SELECT LanguageID FROM @AllLanguages))
	AND (@OnlyPayPalOrders = 0 OR APO.OrderID IS NOT NULL)
	AND (@OnlyCustomFramedOrders = 0 OR O.OrderID IN (SELECT OrderID FROM #AllCustomFramedOrders))
	AND CHARINDEX('Refund', O.OrderType) = 0
	AND CHARINDEX('Reship', O.OrderType) = 0
	AND CHARINDEX('Test', O.OrderType) = 0
	AND O.OrderSource IN (SELECT OrderSource FROM #AllOrderSource)
	GROUP BY
		dbo.TruncTime_DateTime(O.DateCreated),
		DATEPART(DW, O.DateCreated),
		DATEPART(HH, O.DateCreated),
		CONVERT(INT, ((DATEPART(MI, O.DateCreated) / 60.0) * 100) / 25) + 1
	
--	SELECT OrderDate, OrderHour, SUM(Total) AS Total, SUM([Count]) AS OrderCount FROM #T
--	GROUP BY OrderDate, OrderHour
--	ORDER BY 1, 2

	DECLARE @StartQtr SMALLINT, @EndQtr SMALLINT

	SET @StartQtr = CONVERT(INT, ((DATEPART(MI, @StartDate) / 60.0) * 100) / 25) + 1
	SET @EndQtr = CONVERT(INT, ((DATEPART(MI, @EndDate) / 60.0) * 100) / 25) + 1

	SELECT * INTO #T1 FROM #T WHERE OrderHour BETWEEN DATEPART(HH, @StartDate) AND DATEPART(HH, @EndDate)
	AND (OrderHour > DATEPART(HH, @StartDate) OR (OrderHour = DATEPART(HH, @StartDate) AND OrderTimeQtr >= @StartQtr))
	AND (OrderHour < DATEPART(HH, @EndDate) OR (OrderHour = DATEPART(HH, @EndDate) AND OrderTimeQtr <= @EndQtr))

	SELECT T.* 
	INTO #TExcluded
	FROM #T T
		LEFT JOIN #T1 T1 ON T1.OrderDate = T.OrderDate
		AND T1.OrderHour = T.OrderHour
		AND T1.OrderTimeQtr = T.OrderTimeQtr
	WHERE
		T1.OrderDate IS NULL
	AND (T.OrderHour <= DATEPART(HH, @StartDate) OR T.OrderHour >= DATEPART(HH, @EndDate))
	AND ( 
		  (@AdjustmentMethod <> 2 AND (T.OrderHour < DATEPART(HH, @StartDate) OR T.OrderTimeQtr < @StartQtr))
			OR
		  (@AdjustmentMethod <> 1 AND (T.OrderHour > DATEPART(HH, @EndDate) OR T.OrderTimeQtr > @EndQtr))
		)
	AND @AdjustmentMethod BETWEEN 1 AND 3
	
    DECLARE @IncStartDate DATETIME, @HistoryEndDate DATETIME
    SET @IncStartDate = dbo.TruncTime_DateTime(@HDT)
    SET @HistoryEndDate = dbo.TruncTime_DateTime(@StartDate)

    CREATE TABLE #TMissedSales (OrderDate DATETIME)
    CREATE TABLE #TMissedSales_Dash (OrderDate DATETIME)
    
    WHILE @IncStartDate < @EndDate
    BEGIN
        INSERT INTO #TMissedSales (OrderDate) VALUES (@IncStartDate)        
		INSERT INTO #TMissedSales_Dash (OrderDate) VALUES (@IncStartDate) 

        IF NOT EXISTS (SELECT 1 FROM #T1 T WHERE T.OrderDate = @IncStartDate)
        BEGIN
            INSERT INTO #T1 (OrderDate, [WeekDay], OrderHour, OrderTimeQtr, Total, [Count]) VALUES (@IncStartDate, DATEPART(DW, @StartDate), DATEPART(HH, @StartDate), @StartQtr, 0, 0)
        END

        IF NOT EXISTS (SELECT 1 FROM #TExcluded T WHERE T.OrderDate = @IncStartDate)
        BEGIN
            INSERT INTO #TExcluded (OrderDate, [WeekDay], OrderHour, OrderTimeQtr, Total, [Count]) VALUES (@IncStartDate, DATEPART(DW, @StartDate), DATEPART(HH, @StartDate), @StartQtr, 0, 0)
        END
        
        SET @IncStartDate = DATEADD(DD, 7, @IncStartDate)

    END


	SELECT
		IDENTITY(INT, 1, 1) AS Occurance,
		MS.OrderDate,
		SUM(COALESCE(T.Total, 0)) AS [OrderTotal],
		CAST(SUM(COALESCE(T.[Count], 0)) AS FLOAT) AS [OrderCount],
		CAST(0 AS FLOAT) AS [X1],
		CAST(0 AS FLOAT) AS [X2],
		CAST(0 AS FLOAT) AS [OrderTotal_Y1],
		CAST(0 AS FLOAT) AS [OrderTotal_Y1X1],
		CAST(0 AS FLOAT) AS [OrderCount_Y2],
		CAST(0 AS FLOAT) AS [OrderCount_Y2X1]
	INTO #T2
	FROM
        #TMissedSales MS
        LEFT JOIN (
			SELECT 
				OrderDate, 
				SUM(Total) AS Total, 
				SUM([Count]) AS [Count] 
				FROM #T1
			--WHERE
			--		OrderHour >= DATEPART(HH, @StartDate)
			--	AND OrderHour <= DATEPART(HH, @EndDate)
			--	AND (OrderHour <> DATEPART(HH, @StartDate) OR (OrderHour = DATEPART(HH, @StartDate) AND OrderTimeQtr >= @StartQtr))
			--	AND (OrderHour <> DATEPART(HH, @EndDate) OR (OrderHour = DATEPART(HH, @EndDate) AND OrderTimeQtr <= @EndQtr))
			GROUP BY OrderDate
		) T ON MS.OrderDate = T.OrderDate
	WHERE
		(T.OrderDate IS NULL OR T.OrderDate < @ForecastDate)
	GROUP BY MS.OrderDate
    ORDER BY MS.OrderDate
    
    

	DECLARE	
		@MeanX FLOAT, 
		@MeanY_OrderTotal FLOAT, 
		@MeanY_OrderCount FLOAT,
		@b1 FLOAT,
		@b2 FLOAT, 
		@F1 FLOAT, 
		@F2 FLOAT, 
		@a1 FLOAT, 
		@a2 FLOAT
	
	SELECT 
		@MeanX = AVG(CAST(Occurance AS FLOAT)),
		@MeanY_OrderTotal = AVG([OrderTotal]),
		@MeanY_OrderCount = AVG([OrderCount])
	FROM
		#T2


	UPDATE 
		#T2
	SET
		X1 = CAST(Occurance AS FLOAT) - @MeanX,
		X2 = POWER( (Occurance - @MeanX), 2),
		[OrderTotal_Y1] = OrderTotal - @MeanY_OrderTotal,
		[OrderCount_Y2] = OrderCount - @MeanY_OrderCount

	UPDATE 
		#T2
	SET
		[OrderTotal_Y1X1] = [OrderTotal_Y1] * X1,
		[OrderCount_Y2X1] = [OrderCount_Y2] * X1

	
	SELECT 
			@b1 = SUM( [OrderTotal_Y1X1]) / SUM(X2), 
			@b2 = SUM([OrderCount_Y2X1]) / SUM(X2)
	FROM #T2
	

	
	
	SET @a1 = @MeanY_OrderTotal - @b1 * @MeanX
	SET @a2 = @MeanY_OrderCount - @b2 * @MeanX
	SET @F1 = @a1 + @b1 * (@WeeksBack + 1.0)
	SET @F2 = @a2 + @b2 * (@WeeksBack + 1.0)


	--SELECT @A1, @A2, @B1, @B2, @MEANX, @F1, @F2, @WEEKSBACK
	/*
	F = a + bX	
	a = Mean(Y)  - b * Mean(X)
	b = SUM( (x - Mean(x)) * (y - Mean(y))) / SUM( POWER((x - Mean(x)), 2))
	*/

	SELECT 
		CONVERT(VARCHAR(10), OrderDate, 101) AS OrderDate,
		CONVERT(DECIMAL(10, 2), SUM(Total)) AS [OrderTotal],
		SUM([Count]) AS [OrderCount]
	FROM
		#T1 T
	GROUP BY T.OrderDate
	ORDER BY CONVERT(DATETIME, T.OrderDate, 101)

	DECLARE @Gain_Or_Lost_OrderTotal DECIMAL(10, 2), @Gain_Or_Lost_OrderCount INT, @ActualOrderTotal DECIMAL(10, 2), @ActualOrderCount INT

	
    SELECT
		@Gain_Or_Lost_OrderTotal = CONVERT(DECIMAL(10, 2), SUM(Total) - @F1 ) --AS [Gain_Or_Lost_OrderTotal],
		,@Gain_Or_Lost_OrderCount = CONVERT(DECIMAL(10, 2), SUM([Count]) - @F2) -- AS [Gain_Or_Lost_OrderCount],
		--,CONVERT(DECIMAL(10, 2), @F1) --AS Forecast_OrderTotal,
		--,CONVERT(DECIMAL(10, 2), @F2) --AS Forecast_OrderCount,
		,@ActualOrderTotal = CONVERT(DECIMAL(10, 2), SUM(Total)) --AS ActualOrderTotal,
		,@ActualOrderCount = CONVERT(INT, SUM([Count])) --AS ActualOrderCount
	FROM
		#T1
	WHERE
		OrderDate >= dbo.TruncTime_DateTime(@StartDate)


	DECLARE	
		@MeanX_Dash FLOAT, 
		@MeanY_OrderTotal_Dash FLOAT, 
		@MeanY_OrderCount_Dash FLOAT,
		@b1_Dash FLOAT,
		@b2_Dash FLOAT, 
		@F1_Dash FLOAT, 
		@F2_Dash FLOAT, 
		@a1_Dash FLOAT, 
		@a2_Dash FLOAT,
		@Gain_Or_Lost_OrderTotal_DASH DECIMAL(10, 2), 
		@Gain_Or_Lost_OrderCount_DASH INT, 
		@ActualOrderTotal_DASH DECIMAL(10, 2), 
		@ActualOrderCount_DASH INT
		
	IF @AdjustmentMethod BETWEEN 1 AND 3
	BEGIN

		SELECT
			IDENTITY(INT, 1, 1) AS Occurance,
			MS.OrderDate,
			SUM(COALESCE(T.Total, 0)) AS [OrderTotal],
			CAST(SUM(COALESCE(T.[Count], 0)) AS FLOAT) AS [OrderCount],
			CAST(0 AS FLOAT) AS [X1],
			CAST(0 AS FLOAT) AS [X2],
			CAST(0 AS FLOAT) AS [OrderTotal_Y1],
			CAST(0 AS FLOAT) AS [OrderTotal_Y1X1],
			CAST(0 AS FLOAT) AS [OrderCount_Y2],
			CAST(0 AS FLOAT) AS [OrderCount_Y2X1]
		INTO #T2_Dash
		FROM
			#TMissedSales_Dash MS
			LEFT JOIN (
				SELECT 
					OrderDate, 
					SUM(Total) AS Total, 
					SUM([Count]) AS [Count] 
					FROM #TExcluded 
				GROUP BY OrderDate
			) T ON MS.OrderDate = T.OrderDate
		WHERE
			(T.OrderDate IS NULL OR T.OrderDate < @ForecastDate)
		GROUP BY MS.OrderDate
		ORDER BY MS.OrderDate
	    
	    
		SELECT 
			@MeanX_Dash = AVG(CAST(Occurance AS FLOAT)),
			@MeanY_OrderTotal_Dash = AVG([OrderTotal]),
			@MeanY_OrderCount_Dash = AVG([OrderCount])
		FROM
			#T2_Dash
			
		UPDATE 
			#T2_Dash
		SET
			X1 = CAST(Occurance AS FLOAT) - @MeanX_Dash,
			X2 = POWER( (Occurance - @MeanX_Dash), 2),
			[OrderTotal_Y1] = OrderTotal - @MeanY_OrderTotal_Dash,
			[OrderCount_Y2] = OrderCount - @MeanY_OrderCount_Dash
		
		
			
		UPDATE 
			#T2_Dash
		SET
			[OrderTotal_Y1X1] = [OrderTotal_Y1] * X1,
			[OrderCount_Y2X1] = [OrderCount_Y2] * X1
		
		SELECT 
				@b1_Dash = SUM( [OrderTotal_Y1X1]) / SUM(X2), 
				@b2_Dash = SUM([OrderCount_Y2X1]) / SUM(X2)
		FROM #T2_Dash
		
		
		SET @a1_Dash = @MeanY_OrderTotal_Dash - @b1_Dash * @MeanX_Dash
		SET @a2_Dash = @MeanY_OrderCount_Dash - @b2_Dash * @MeanX_Dash
		SET @F1_Dash = @a1_Dash + @b1_Dash * (@WeeksBack + 1.0)
		SET @F2_Dash = @a2_Dash + @b2_Dash * (@WeeksBack + 1.0)

		SELECT
			@Gain_Or_Lost_OrderTotal_DASH = CONVERT(DECIMAL(10, 2), SUM(Total) - @F1_Dash ) --AS [Gain_Or_Lost_OrderTotal],
			,@Gain_Or_Lost_OrderCount_DASH = CONVERT(DECIMAL(10, 2), SUM([Count]) - @F2_Dash) -- AS [Gain_Or_Lost_OrderCount],
			--,CONVERT(DECIMAL(10, 2), @F1_Dash) --AS Forecast_OrderTotal,
			--,CONVERT(DECIMAL(10, 2), @F2_Dash) --AS Forecast_OrderCount,
			,@ActualOrderTotal_DASH = CONVERT(DECIMAL(10, 2), SUM(Total)) --AS ActualOrderTotal,
			,@ActualOrderCount_DASH = CONVERT(INT, SUM([Count])) --AS ActualOrderCount
		FROM
			#TExcluded
		WHERE
			OrderDate >= dbo.TruncTime_DateTime(@StartDate)
		
	END
	
	

	DECLARE @GainOrLostOrderTotalPCT FLOAT, @GainOrLostOrderCountPCT FLOAT
	
	IF @F1_Dash <> 0
	BEGIN
		SET @GainOrLostOrderTotalPCT = @Gain_Or_Lost_OrderTotal_DASH / @F1_Dash
	END
	ELSE
	BEGIN
		SET @GainOrLostOrderTotalPCT = NULL
	END
	
	IF @F2_Dash <> 0
	BEGIN
		SET @GainOrLostOrderCountPCT = @Gain_Or_Lost_OrderCount_DASH / @F2_Dash
	END
	ELSE
	BEGIN
		SET @GainOrLostOrderCountPCT = NULL
	END
	
	SELECT
		@Gain_Or_Lost_OrderTotal AS [Gain_Or_Lost_OrderTotal],
		@Gain_Or_Lost_OrderCount AS [Gain_Or_Lost_OrderCount],
		CONVERT(DECIMAL(10, 2), @F1) AS Forecast_OrderTotal,
		CONVERT(DECIMAL(10, 2), @F2) AS Forecast_OrderCount,
		@ActualOrderTotal AS ActualOrderTotal,
		@ActualOrderCount AS ActualOrderCount,
		CONVERT(DECIMAL(10, 2), @GainOrLostOrderTotalPCT * 100) AS Adjusted_GainOrLostOrderTotalPCT,
		CONVERT(DECIMAL(10, 2), @GainOrLostOrderCountPCT * 100) AS Adjusted_GainOrLostOrderCountPCT,
		CONVERT(DECIMAL(10, 2), @Gain_Or_Lost_OrderTotal + (@ActualOrderTotal + @F1 * @GainOrLostOrderTotalPCT)) AS [Adjusted_Gain_Or_Lost_OrderTotal],
		CONVERT(DECIMAL(10, 2), @Gain_Or_Lost_OrderCount + (@ActualOrderCount + @F2 * @GainOrLostOrderCountPCT)) AS  [Adjusted_Gain_Or_Lost_OrderCount]
		
	SELECT 
		CONVERT(VARCHAR(10), OrderDate, 101) AS OrderDate,
		OrderHour AS OrderHour,
		CONVERT(DECIMAL(10, 2), SUM(Total)) AS [OrderTotal],
		CONVERT(DECIMAL(10, 2), SUM([Count])) AS [OrderCount]
	FROM
		#T1 T
	WHERE
		OrderHour >= DATEPART(HH, @StartDate)
	AND OrderHour <= DATEPART(HH, @EndDate)
	AND (OrderHour <> DATEPART(HH, @StartDate) OR (OrderHour = DATEPART(HH, @StartDate) AND OrderTimeQtr >= @StartQtr))
	AND (OrderHour <> DATEPART(HH, @EndDate) OR (OrderHour = DATEPART(HH, @EndDate) AND OrderTimeQtr <= @EndQtr))
	GROUP BY T.OrderDate, T.OrderHour
	ORDER BY CONVERT(DATETIME, T.OrderDate, 101), T.OrderHour

	
END



/*
Purpose: To extract cart XML data


DROP TABLE #tmpXMLTable

*/
USE ArtPublicDB

DECLARE @OrderXML AS XML
DECLARE @DateCreated AS DATETIME
DECLARE @NodeValue AS VARCHAR(1000)
DECLARE @SalesOrderQueueID INT
	, @ReferenceOID VARCHAR(35)
	, @OrderSource VARCHAR(35)
	, @TotalAmount AS MONEY
	, @CartKey VARCHAR(35)
	, @PaymentType VARCHAR(50)
	, @FirstName VARCHAR(50)
	, @LastName VARCHAR(50)
	, @CompanyName VARCHAR(50)
	, @Address1 VARCHAR(50)
	, @Address2 VARCHAR(50)
	, @City VARCHAR(50)
	, @State VARCHAR(50)
	, @ZipCode VARCHAR(50)
	, @Country VARCHAR(50)
	, @Phone VARCHAR(50)
	, @PayerEmail VARCHAR(50)
	, @ReceiverEmail VARCHAR(50)
	, @Token VARCHAR(50)
	, @PayerId VARCHAR(50)
	, @AuthorizationId VARCHAR(50)


CREATE TABLE #tmpXMLTable (
	XMLTableID INT IDENTITY(1, 1)
	, SalesOrderQueueID  INT
	, ReferenceOID VARCHAR(35)
	, OrderSource VARCHAR(35)
	, TotalAmount MONEY
	, CartKey VARCHAR(35)
	, PaymentType VARCHAR(50)
	, FirstName VARCHAR(50)
	, LastName VARCHAR(50)
	, CompanyName VARCHAR(50)
	, Address1 VARCHAR(50)
	, Address2 VARCHAR(50)
	, City VARCHAR(50)
	, State VARCHAR(50)
	, ZipCode VARCHAR(50)
	, Country VARCHAR(50)
	, Phone VARCHAR(50)
	, PayerEmail VARCHAR(50)
	, ReceiverEmail VARCHAR(50)
	, Token VARCHAR(50)
	, PayerId VARCHAR(50)
	, AuthorizationId VARCHAR(50)
	)

-- Cursor Definition
DECLARE CartCursor INSENSITIVE CURSOR FOR
SELECT CartKey, OrderXML, DateCreated, SalesOrderQueueID
FROM dCart_Universal.dbo.tblSalesOrderQueue (NOLOCK)
WHERE Status = 'New'
	AND LEN(OrderNumber) = 0

OPEN CartCursor 

FETCH NEXT FROM CartCursor INTO @CartKey, @OrderXML, @DateCreated, @SalesOrderQueueID 

-- while loop
WHILE (@@FETCH_STATUS = 0 )
BEGIN
	-- Getting ReferenceOID
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Summary/PaymentOrderReference', @NodeValue OUTPUT
	SELECT @ReferenceOID = @NodeValue

	-- Getting ReferenceOID
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Summary/Source', @NodeValue OUTPUT
	SELECT @OrderSource = @NodeValue

	-- Getting TotalAmount
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Summary/PaymentSummary/TotalAmount', @NodeValue OUTPUT
	SELECT @TotalAmount = @NodeValue

	-- Getting PaymentType
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/ApplicationType', @NodeValue OUTPUT
	SELECT @PaymentType = @NodeValue

	-- Getting FirstName
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Name/First', @NodeValue OUTPUT
	SELECT @FirstName = @NodeValue

	-- Getting LastName
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Name/Last', @NodeValue OUTPUT
	SELECT @LastName = @NodeValue

	-- Getting CompanyName
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/CompanyName', @NodeValue OUTPUT
	SELECT @CompanyName = @NodeValue

	-- Getting Address1
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Address1', @NodeValue OUTPUT
	SELECT @Address1 = @NodeValue

	-- Getting Address2
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Address2', @NodeValue OUTPUT
	SELECT @Address2 = @NodeValue

	-- Getting City
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/City', @NodeValue OUTPUT
	SELECT @City = @NodeValue

	-- Getting State
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/State', @NodeValue OUTPUT
	SELECT @State = @NodeValue

	-- Getting ZipCode
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/ZipCode', @NodeValue OUTPUT
	SELECT @ZipCode = @NodeValue

	-- Getting Country
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Country/Name', @NodeValue OUTPUT
	SELECT @Country = @NodeValue

	-- Getting Phone
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/TranslatedAddress/Address/Phone/Primary', @NodeValue OUTPUT
	SELECT @Phone = @NodeValue

	-- Getting Paypal Payer Email
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/Paypal/PayerEmail', @NodeValue OUTPUT
	SELECT @PayerEmail = @NodeValue

	-- Getting Paypal Receiver Email
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/Paypal/ReceiverEmail', @NodeValue OUTPUT
	SELECT @ReceiverEmail = @NodeValue

	-- Getting Paypal Token
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/Paypal/Token', @NodeValue OUTPUT
	SELECT @Token = @NodeValue

	-- Getting Paypal PayerID
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/Paypal/PayerId', @NodeValue OUTPUT
	SELECT @PayerId = @NodeValue

	-- Getting Paypal AuthorizationId
	EXEC spsGetAttributesFromOrderXML @OrderXML, '/Cart/Payments/Payment/Paypal/AuthorizationId', @NodeValue OUTPUT
	SELECT @AuthorizationId = @NodeValue

	INSERT INTO #tmpXMLTable (SalesOrderQueueID , ReferenceOID, TotalAmount, CartKey, PaymentType, FirstName 
			, LastName, CompanyName, Address1, Address2, City 
			, State, ZipCode, Country, Phone, OrderSource
			, PayerEmail, ReceiverEmail, Token, PayerID, AuthorizationId 
			)
	VALUES (@SalesOrderQueueID, @ReferenceOID, @TotalAmount, @CartKey, @PaymentType, @FirstName 
			, @LastName, @CompanyName, @Address1, @Address2, @City 
			, @State, @ZipCode, @Country, @Phone, @OrderSource
			, @PayerEmail, @ReceiverEmail, @Token, @PayerID, @AuthorizationId 
			)
	FETCH NEXT FROM CartCursor INTO @CartKey, @OrderXML, @DateCreated, @SalesOrderQueueID 
END

-- closing the cursor
CLOSE CartCursor 
DEALLOCATE CartCursor 


-- Display Result
SELECT * FROM #tmpXMLTable


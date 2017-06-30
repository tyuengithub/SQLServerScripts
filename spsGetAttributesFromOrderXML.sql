CREATE PROCEDURE dbo.spsGetAttributesFromOrderXML(
      @SalesOrderXML XML
	, @NodeName VARCHAR(500) 
	, @NodeValue NVARCHAR(1000) OUTPUT
)

/*
	Purpose: To extract data from a given XML node path
		- pass the XML Node Path and Node Name, output the value
	Created By: Tommy Yuen
	Created Date: 3/1/2013
*/

AS


BEGIN

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @Query NVARCHAR(4000), @Param NVARCHAR(1000)
	SET @Query = N'
            WITH XMLNAMESPACES (default ''http://xmlns.art.com/order'')
            SELECT
                  @NodeValue = @SalesOrderXML.value(''('+@NodeName+')[1]'', ''NVARCHAR(500)'')
		'

      SET @Param = N'@SalesOrderXML XML, @NodeValue NVARCHAR(1000) OUTPUT'

	EXEC sp_executesql @Query, @Param, @SalesOrderXML = @SalesOrderXML, @NodeValue = @NodeValue OUTPUT

END


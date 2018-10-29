	-- Rollup By Month and Year
	DECLARE @listCol VARCHAR(2000)
	DECLARE @SQLStr NVARCHAR(4000)

	SELECT  @listCol = STUFF(( 
						SELECT DISTINCT
								'],[' + RIGHT('0' + CAST(MONTH(DateLastModified) AS VARCHAR(2)), 2)
						FROM tblCartDetail (NOLOCK)
						GROUP BY MONTH(DateLastModified)
							ORDER BY '],[' + RIGHT('0' + CAST(MONTH(DateLastModified) AS VARCHAR(2)), 2)
							FOR XML PATH('')
										), 1, 2, '') + ']'

	-- pivot the summary
	SET @SQLStr = N'SELECT *
	FROM  
		(
		SELECT YEAR(DateLastModified) AS [Year]
			, MONTH(DateLastModified) AS [Month]
			, COUNT(1) AS NumOfCart
		FROM tblCartDetail (NOLOCK)
		GROUP BY YEAR(DateLastModified), MONTH(DateLastModified)
		) AS TableToBePivoted   
	PIVOT   
	(	
		SUM(NumOfCart)   
		FOR [Month] IN (' + @ListCol + ')   
	) AS PivotedTable
	ORDER BY 1 DESC'

	-- print @SQLStr
	EXECUTE dbo.sp_executesql @SQLStr

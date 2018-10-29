USE dBuilder_Master
GO

CREATE FUNCTION dbo.fnRoundDownToNearest5Or9 (@OriginalInput VARCHAR(20))
/*
09-08-2017: Tommy Yuen: Create function to round down to the nearest 5 or 9
*/
RETURNS INT

AS
BEGIN
	DECLARE @Input AS VARCHAR(200)
		, @FinalPrice INT

	SELECT  @Input = @OriginalInput

	-- Get to the nearest whole unit
	SELECT  @Input = CAST(FLOOR(@Input) AS INT)

	SELECT @FinalPrice = 
		CASE 
			-- if the last digit is between 0 to 4, then minus the first digit and add 1 to get to 9
			WHEN RIGHT(@Input, 1) BETWEEN 0 AND 4 THEN @Input - 1 - RIGHT(@Input, 1) 
			
			-- if the last digit is between 6 to 8, then minus the first digit and add 5 to get 5
			WHEN RIGHT(@Input, 1) BETWEEN 6 AND 8 THEN @Input + 5 - RIGHT(@Input, 1)

			-- nothing to be done if it is already ends 5 or 9
			ELSE @Input
		END 

	RETURN @FinalPrice
END


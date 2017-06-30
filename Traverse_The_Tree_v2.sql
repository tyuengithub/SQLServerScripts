SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @CategoryID INT = 154940;

-- this will show the all the child categories of the category
WITH category AS(
			SELECT tblCategoryRelationShip.ParentCategoryID
				, tblCategoryRelationShip.CategoryID
				, tlkCategoryStatus.Description AS CategoryStatus
				, CategoryPath = CAST(tblCategoryRelationShip.CategoryID AS VARCHAR(8000))
				, CategoryPathName = CAST(Name AS VARCHAR(8000))
				, TreeLevel = 1
			FROM tblCategoryRelationShip
				INNER JOIN tblCategory ON tblCategoryRelationShip.CategoryID = tblCategory.CategoryID
				INNER JOIN tlkCategoryStatus ON tlkCategoryStatus.CategoryStatusID = tblCategory.CategoryStatusID
			WHERE tblCategoryRelationShip.CategoryID = @CategoryID

			UNION ALL

			SELECT parent.ParentCategoryID
				, parent.CategoryID 
				, tlkCategoryStatus.Description AS CategoryStatus
				, CategoryPath = CategoryPath + ' -> ' + CAST(parent.CategoryID AS VARCHAR(8000))
				, CategoryPathName = CategoryPathName + ' -> ' + CAST(tblCategory.Name AS VARCHAR(8000)) 
				, TreeLevel = TreeLevel + 1
			FROM tblCategoryRelationShip parent
				INNER JOIN category child ON child.CategoryID = parent.ParentCategoryID
				INNER JOIN tblCategory ON parent.CategoryID = tblCategory.CategoryID
				INNER JOIN tlkCategoryStatus ON tlkCategoryStatus.CategoryStatusID = tblCategory.CategoryStatusID

			)
SELECT * FROM category
OPTION (maxrecursion 0);


-- this show all the "parent categories", also known as the category path
WITH category AS(
			SELECT tblCategoryRelationShip.ParentCategoryID
				, tblCategoryRelationShip.CategoryID
				, tlkCategoryStatus.Description AS CategoryStatus
				, CategoryPath = CAST(tblCategoryRelationShip.ParentCategoryID AS VARCHAR(8000)) + ' -> ' + CAST(tblCategoryRelationShip.CategoryID AS VARCHAR(8000))
				, CategoryPathName = CAST(parentname.Name AS VARCHAR(8000)) + ' -> ' + CAST(tblCategory.Name AS VARCHAR(8000))
				, TreeLevel = 2
			FROM tblCategoryRelationShip
				INNER JOIN tblCategory ON tblCategoryRelationShip.CategoryID = tblCategory.CategoryID
				INNER JOIN tblCategory parentname ON tblCategoryRelationShip.ParentCategoryID = parentname.CategoryID 
				INNER JOIN tlkCategoryStatus ON tlkCategoryStatus.CategoryStatusID = tblCategory.CategoryStatusID
			WHERE tblCategoryRelationShip.CategoryID = @CategoryID

			UNION ALL

			SELECT parent.ParentCategoryID
				, parent.CategoryID 
				, tlkCategoryStatus.Description AS CategoryStatus
				, CategoryPath = CAST(parent.ParentCategoryID AS VARCHAR(8000)) + ' -> ' + CategoryPath 
				, CategoryPathName = CAST(tblCategory.Name AS VARCHAR(8000))  + ' -> ' + CategoryPathName
				, TreeLevel = TreeLevel + 1
			FROM tblCategoryRelationShip parent
				INNER JOIN category child ON child.ParentCategoryID = parent.CategoryID
				INNER JOIN tblCategory ON parent.ParentCategoryID = tblCategory.CategoryID
				INNER JOIN tblCategory childcat ON childcat.CategoryID = child.ParentCategoryID
				INNER JOIN tlkCategoryStatus ON tlkCategoryStatus.CategoryStatusID = childcat.CategoryStatusID
			)
SELECT * FROM category
ORDER BY TreeLevel
OPTION (maxrecursion 0)

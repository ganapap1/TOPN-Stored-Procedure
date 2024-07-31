USE [SuperStoreDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_DynamicSimpleTopNGenerator]    Script Date: 31-07-2024 12:44:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_DynamicSimpleTopNGenerator]
    @TableName NVARCHAR(MAX),
    @GroupColumn NVARCHAR(MAX),
    @ValueColumn NVARCHAR(MAX),
    @TopGroupCount INT,
    @RequireOthers BIT,
    @GetMeQuery BIT,
    @RenameColumnResults BIT
AS
BEGIN
    -- Declare variables
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @GroupRankAlias NVARCHAR(MAX);
    DECLARE @OtherGroupAlias NVARCHAR(MAX);
    DECLARE @OrderDirection NVARCHAR(4);

    -- Assign values to the rank alias variables
    SET @GroupRankAlias = @GroupColumn + '_rank';
    SET @OtherGroupAlias = 'Other ' + @GroupColumn;


    -- Construct the dynamic SQL query
    SET @sql = N'
    WITH GroupValues AS (
        SELECT
            ' + QUOTENAME(@GroupColumn) + ' AS GroupColumnName,
            SUM(' + QUOTENAME(@ValueColumn) + ') AS GroupTotalValue,
            ROW_NUMBER() OVER (ORDER BY SUM(' + QUOTENAME(@ValueColumn) + ') DESC) AS GroupRank
        FROM ' + QUOTENAME(@TableName) + '
        GROUP BY ' + QUOTENAME(@GroupColumn) + '
    ),
    TopGroup AS (
        SELECT
            CASE
                WHEN GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN GroupColumnName
                ELSE ''' + @OtherGroupAlias + '''
            END AS GroupColumn_Name,
            SUM(GroupTotalValue) AS GroupTotalValue,
            CASE
                WHEN GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN GroupRank
                ELSE ' + CAST(@TopGroupCount + 1 AS NVARCHAR) + '
            END AS GroupRank
        FROM GroupValues
        GROUP BY
            CASE
                WHEN GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN GroupColumnName
                ELSE ''' + @OtherGroupAlias + '''
            END,
            CASE
                WHEN GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN GroupRank
                ELSE ' + CAST(@TopGroupCount + 1 AS NVARCHAR) + '
            END
    )';

    -- Append the SELECT statement 
	IF @RenameColumnResults = 0
	BEGIN
		SET @sql = @sql + '
		SELECT 
			GroupColumn_Name ,
			GroupTotalValue ,
			GroupRank 
		FROM TopGroup ';
	END
	ELSE
	BEGIN
		SET @sql = @sql + '
		SELECT 
			GroupColumn_Name AS ' + QUOTENAME(@GroupColumn, '''') + ',
			GroupTotalValue AS ' + QUOTENAME(@ValueColumn, '''') + ',
			GroupRank AS ' + QUOTENAME(@GroupRankAlias, '''') + '
		FROM TopGroup ';
	END

	IF @RequireOthers = 0
    BEGIN
        SET @sql = @sql + 'WHERE GroupRank <> ' + CAST(@TopGroupCount + 1 AS NVARCHAR) + ' ';
    END

    SET @sql = @sql + 
	'ORDER BY 
	GroupRank, GroupTotalValue DESC;' ;
	
	IF @GetMeQuery = 1
	BEGIN
		--SELECT @sql AS GeneratedSQLQuery
		-- Printing query itself
		PRINT @sql; 
	END
	ELSE
	BEGIN
    -- Execute the constructed SQL query
		EXEC sp_executesql @sql;
	END
END

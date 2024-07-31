USE [SuperStoreDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_DynamicNestedTopNGenerator]    Script Date: 31-07-2024 12:44:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_DynamicNestedTopNGenerator]
    @TableName NVARCHAR(MAX),
    @GroupColumn NVARCHAR(MAX),
    @SubgroupColumn NVARCHAR(MAX),
    @ValueColumn NVARCHAR(MAX),
    @TopGroupCount INT,
    @TopSubgroupCount INT,
    @RequireOthers BIT,
    @GetMeQuery BIT,
    @RenameColumnResults BIT
AS
BEGIN
    -- Declare variables
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @GroupRankAlias NVARCHAR(MAX);
    DECLARE @SubgroupRankAlias NVARCHAR(MAX);
    DECLARE @OtherGroupAlias NVARCHAR(MAX);
    DECLARE @OtherSubgroupAlias NVARCHAR(MAX);
    DECLARE @OrderDirection NVARCHAR(4);

    -- Assign values to the rank alias variables
    SET @GroupRankAlias = @GroupColumn + '_rank';
    SET @SubgroupRankAlias = @SubgroupColumn + '_rank';
    SET @OtherGroupAlias = 'Other ' + @GroupColumn;
    SET @OtherSubgroupAlias = 'Other ' + @SubgroupColumn;


    -- Construct the dynamic SQL query
    SET @sql = N'
    WITH GroupValues AS (
        SELECT
            ' + QUOTENAME(@GroupColumn) + ' AS GroupColumnName,
            SUM(' + QUOTENAME(@ValueColumn) + ') AS GroupTotalValue,
            ROW_NUMBER() OVER (ORDER BY SUM(' + QUOTENAME(@ValueColumn) + ')  DESC) AS GroupRank
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
    ),
    SubgroupValues AS (
        SELECT
            ' + QUOTENAME(@GroupColumn) + ' AS GroupColumnName,
            ' + QUOTENAME(@SubgroupColumn) + ' AS SubgroupColumnName,
            SUM(' + QUOTENAME(@ValueColumn) + ') AS SubgroupTotalValues,
            ROW_NUMBER() OVER (PARTITION BY ' + QUOTENAME(@GroupColumn) + ' ORDER BY SUM(' + QUOTENAME(@ValueColumn) + ') DESC) AS SubgroupRank
        FROM ' + QUOTENAME(@TableName) + '
        GROUP BY ' + QUOTENAME(@GroupColumn) + ', ' + QUOTENAME(@SubgroupColumn) + '
    ),
    TopSubgroup AS (
        SELECT
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN cs.GroupColumnName
                ELSE ''' + @OtherGroupAlias + '''
            END AS GroupColumn_Name,
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' AND cs.SubgroupRank <= ' + CAST(@TopSubgroupCount AS NVARCHAR) + ' THEN cs.SubgroupColumnName
                ELSE ''' + @OtherSubgroupAlias + '''
            END AS SubgroupColumnName,
            SUM(cs.SubgroupTotalValues) AS SubgroupTotalValues,
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' AND cs.SubgroupRank <= ' + CAST(@TopSubgroupCount AS NVARCHAR) + ' THEN cs.SubgroupRank
                ELSE ' + CAST(@TopSubgroupCount + 1 AS NVARCHAR) + '
            END AS SubgroupRank,
            COALESCE(ts.GroupRank, ' + CAST(@TopGroupCount + 1 AS NVARCHAR) + ') AS GroupRank
        FROM SubgroupValues cs
        LEFT JOIN TopGroup ts ON cs.GroupColumnName = ts.GroupColumn_Name 
        GROUP BY
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' THEN cs.GroupColumnName
                ELSE ''' + @OtherGroupAlias + '''
            END,
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' AND cs.SubgroupRank <= ' + CAST(@TopSubgroupCount AS NVARCHAR) + ' THEN cs.SubgroupColumnName
                ELSE ''' + @OtherSubgroupAlias + '''
            END,
            CASE
                WHEN ts.GroupRank <= ' + CAST(@TopGroupCount AS NVARCHAR) + ' AND cs.SubgroupRank <= ' + CAST(@TopSubgroupCount AS NVARCHAR) + ' THEN cs.SubgroupRank
                ELSE ' + CAST(@TopSubgroupCount + 1 AS NVARCHAR) + '
            END,
            ts.GroupRank
    )
    ';

    -- Append the SELECT statement based on the @RequireOthers parameter
	IF @RenameColumnResults = 0
	BEGIN
		SET @sql = @sql + '
		SELECT 
			GroupColumn_Name ,
			SubgroupColumnName ,
			SubgroupTotalValues ,
			GroupRank ,
			SubgroupRank 
		FROM TopSubgroup ';
	END
	ELSE
	BEGIN
	    SET @sql = @sql + '
		SELECT 
			GroupColumn_Name AS ' + QUOTENAME(@GroupColumn, '''') + ',
			SubgroupColumnName AS ' + QUOTENAME(@SubgroupColumn, '''') + ',
			SubgroupTotalValues AS ' + QUOTENAME(@ValueColumn, '''') + ',
			GroupRank AS ' + QUOTENAME(@GroupRankAlias, '''') + ',
			SubgroupRank  AS ' + QUOTENAME(@SubgroupRankAlias, '''') + '
		FROM TopSubgroup ';
	END


    IF @RequireOthers = 0
    BEGIN
        SET @sql = @sql + 'WHERE SubgroupRank <= ' + CAST(@TopSubgroupCount AS NVARCHAR) + ' ';
    END

    SET @sql = @sql + 
	'ORDER BY 
	GroupRank, SubgroupRank, SubgroupTotalValues DESC ' ;
	
	IF @GetMeQuery = 1
	BEGIN
		-- SELECT @sql AS GeneratedSQLQuery
		-- Printing query itself
		PRINT @sql; 
	END
	ELSE
	BEGIN
		-- Execute the constructed SQL query
		EXEC sp_executesql @sql;
	END
END

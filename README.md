# TOPN-Stored-Procedure
Stored Procedure both Simple and Nested to analyze any table
you have multiple parameters to declare as shown below, which makes the stored procedure highly dynamic


EXEC dbo.sp_DynamicSimpleTopNGenerator
    @TableName ='superstore_dataset', 
    @GroupColumn ='state',
    @ValueColumn ='sales',
    @TopGroupCount = 10,      -- provide TOP N count eg Top 10 Cities 
	  @RequireOthers = 1,       -- if 1, eg Rank more than 10 will be summarised in a separate row as Rank 11
	  @GetMeQuery = 0,          -- if 1, you get the query, otherwise you get a extract as table
	  @RenameColumnResults = 1  -- if 1, you get the Column Names renamed in output, otherwise standard Names


	
EXEC dbo.sp_DynamicNestedTopNGenerator
    @TableName ='superstore_dataset',
    @GroupColumn ='state',
    @SubgroupColumn ='customer',
    @ValueColumn ='sales',
    @TopGroupCount = 10,      -- provide TOP N count main group eg Top 10 States
    @TopSubgroupCount = 5,    -- provide TOP N count eg Top 5 cities within top 10 States
	  @RequireOthers = 1,       -- if 1, eg Rank more than 10 will be summarised in a separate row as Rank 11
	  @GetMeQuery = 0,          -- if 1, you get the query, otherwise you get a extract as table
	  @RenameColumnResults = 1  -- if 1, you get the Column Names renamed in output, otherwise standard Names


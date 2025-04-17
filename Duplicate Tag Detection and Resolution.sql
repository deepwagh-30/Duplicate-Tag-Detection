use Debtor
go


-- 1 Identify Duplicate Material IDs
SELECT 
    MaterialID,
    COUNT(MaterialID) AS RecordCount
FROM [dbo].[Asset_Data]
GROUP BY MaterialID
HAVING COUNT(MaterialID)  > 1
ORDER BY RecordCount DESC; 

-- 2 Examine the Duplicate Records in Detail

WITH DuplicateMaterials AS (
    SELECT MaterialID
    FROM [dbo].[Asset_Data]
    GROUP BY MaterialID
    HAVING COUNT(*) > 1
)
SELECT m.*
FROM [dbo].[Asset_Data] m
INNER JOIN DuplicateMaterials d ON m.MaterialID = d.MaterialID
ORDER BY m.MaterialID; 

-- 3. Find Inconsistencies in Duplicate Records

WITH MaterialGroups AS (
    SELECT 
        MaterialID,
        COUNT(DISTINCT MaterialDescription) AS UniqueDescCount,
        COUNT(DISTINCT MaterialType) AS UniqueTypeCount,
        COUNT(DISTINCT UnitOfMeasure) AS UniqueUOMCount,
        COUNT(DISTINCT MaterialGroup) AS UniqueGroupCount,
        COUNT(DISTINCT Status) AS UniqueStatusCount
    FROM [dbo].[Asset_Data]
    GROUP BY MaterialID
    HAVING COUNT(MaterialID) > 1
)
SELECT *
FROM MaterialGroups
WHERE UniqueDescCount > 1 
   OR UniqueTypeCount > 1 
   OR UniqueUOMCount > 1 
   OR UniqueGroupCount > 1 
   OR UniqueStatusCount > 1; 

CREATE TABLE #ConsolidatedMaterials (
    MaterialID VARCHAR(10),
    MaterialDesc NVARCHAR(255),
    MaterialType NVARCHAR(50),
    UnitOfMeasure NVARCHAR(50),
    MaterialGroup NVARCHAR(50),
    Status NVARCHAR(20),
    CreatedDate DATETIME,
    Weight DECIMAL(10,2)
);

-- Creation of temp table 
CREATE TABLE #ConsolidatedMaterial (
    MaterialID NVARCHAR,
    MaterialDesc NVARCHAR(MAX),
    MaterialType NVARCHAR(MAX),
    UnitOfMeasure NVARCHAR(MAX),
    MaterialGroup NVARCHAR(MAX),
    Status NVARCHAR(50),
    CreatedDate DATETIME,
    Weight FLOAT
);





-- 4 Insert consolidated records, taking the most recent for each MaterialID

INSERT INTO #ConsolidatedMaterial
SELECT 
    m.MaterialID,
    FIRST_VALUE(m.MaterialDescription) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS MaterialDesc,
    FIRST_VALUE(m.MaterialType) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS MaterialType,
    FIRST_VALUE(m.UnitOfMeasure) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS UnitOfMeasure,
    FIRST_VALUE(m.MaterialGroup) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS MaterialGroup,
    FIRST_VALUE(m.Status) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS Status,
    MAX(m.CreatedDate) OVER (PARTITION BY m.MaterialID) AS CreatedDate,
    FIRST_VALUE(m.Weight) OVER (PARTITION BY m.MaterialID ORDER BY 
        CASE WHEN m.Status = 'Active' THEN 1 
             WHEN m.Status = 'Under Review' THEN 2
             ELSE 3 END,
        m.CreatedDate DESC) AS Weight
FROM [dbo].[Asset_Data] m;

-- Remove duplicates by using ROW_NUMBER()
WITH RankedRecords AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY MaterialID ORDER BY CreatedDate DESC) AS RowNum
    FROM #ConsolidatedMaterials
)
DELETE FROM RankedRecords WHERE RowNum > 1;

-- Verify consolidated materials
SELECT * FROM #ConsolidatedMaterials ORDER BY MaterialID;


BEGIN TRANSACTION;

-- Delete all existing records for the duplicate MaterialIDs

DELETE FROM Materials
WHERE MaterialID IN (SELECT MaterialID FROM #ConsolidatedMaterials);

-- Insert the consolidated records
INSERT INTO Materials
SELECT MaterialID, MaterialDesc, MaterialType, UnitOfMeasure, MaterialGroup, Status, CreatedDate, Weight
FROM #ConsolidatedMaterials;

COMMIT TRANSACTION;

-- Clean up
DROP TABLE #ConsolidatedMaterial;

-- 5. Identify Similar Materials with Different IDs (Potential Duplicates)

SELECT 
    m1.MaterialID AS MaterialID1,
    m2.MaterialID AS MaterialID2,
    m1.MaterialDescription,
    m1.MaterialType,
    m1.MaterialGroup,
    m1.UnitOfMeasure
FROM [dbo].[Asset_Data] m1
JOIN [dbo].[Asset_Data] m2 ON 
    m1.MaterialDescription = m2.MaterialDescription AND
    m1.MaterialType = m2.MaterialType AND
    m1.MaterialGroup = m2.MaterialGroup AND
    m1.UnitOfMeasure = m2.UnitOfMeasure AND
    m1.MaterialID < m2.MaterialID
ORDER BY m1.MaterialDescription, m1.MaterialType;

-- 6. Check Vendor References to Materials
-- Find vendors referencing materials that have duplicates

WITH DuplicateMaterialIDs AS (
    SELECT MaterialID
    FROM [dbo].[Asset_Data]
    GROUP BY MaterialID
    HAVING COUNT(*) > 1
)
SELECT v.*
FROM [dbo].[Vendor_Master_Data] v
INNER JOIN DuplicateMaterialIDs dm ON v.MaterialID = dm.MaterialID
ORDER BY v.MaterialID;

-- Identify patterns in contact numbers
SELECT 
    CASE 
        WHEN ContactNumber LIKE '+%' THEN 'International Format'
        WHEN ContactNumber LIKE '00%' THEN 'International with 00'
        WHEN ContactNumber LIKE '(%)%' THEN 'With Parentheses'
        WHEN ContactNumber LIKE '%x%' THEN 'With Extension'
        WHEN ContactNumber LIKE '-%' THEN 'Negative Format'
        ELSE 'Other Format'
    END AS NumberFormat,
    COUNT(*) AS Count
FROM Vendors
GROUP BY CASE 
        WHEN ContactNumber LIKE '+%' THEN 'International Format'
        WHEN ContactNumber LIKE '00%' THEN 'International with 00'
        WHEN ContactNumber LIKE '(%)%' THEN 'With Parentheses'
        WHEN ContactNumber LIKE '%x%' THEN 'With Extension'
        WHEN ContactNumber LIKE '-%' THEN 'Negative Format'
        ELSE 'Other Format'
    END
ORDER BY Count DESC;

-- Standardize contact numbers (example)
SELECT
    VendorID,
    ContactNumber AS OriginalNumber,
    CASE
        WHEN ContactNumber LIKE '+%' THEN ContactNumber
        WHEN ContactNumber LIKE '00%' THEN REPLACE(ContactNumber, '00', '+')
        WHEN ContactNumber LIKE '%x%' THEN 
            SUBSTRING(ContactNumber, 1, CHARINDEX('x', ContactNumber) - 1) + 
            ' ext. ' + 
            SUBSTRING(ContactNumber, CHARINDEX('x', ContactNumber) + 1, LEN(ContactNumber))
        WHEN ContactNumber LIKE '-%' THEN SUBSTRING(ContactNumber, 2, LEN(ContactNumber))
        ELSE ContactNumber
    END AS StandardizedNumber
FROM [dbo].[Vendor_Master_Data]
WHERE ContactNumber IS NOT NULL; 




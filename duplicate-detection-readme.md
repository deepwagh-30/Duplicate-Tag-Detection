# Duplicate Tag Detection and Resolution Strategy

## Overview
This repository contains SQL scripts for identifying and resolving duplicate records in a database system with vendor and material tables. The scripts are designed to work in SQL Server Management Studio (SSMS) and provide a comprehensive approach to data cleansing and quality improvement.

## Problem Statement
The database contains several data quality issues including:
- Duplicate MaterialIDs in the materials table
- Inconsistent contact number formats
- Data inconsistencies with status values
- Possible duplicate records with slightly different information

## Repository Contents
- `identify_duplicates.sql`: Scripts to detect duplicate records
- `analyze_inconsistencies.sql`: Scripts to examine details of duplicate records
- `resolution_strategy.sql`: Procedures for merging and consolidating duplicates
- `data_standardization.sql`: Scripts for standardizing data formats like contact numbers
- `similar_records.sql`: Scripts to find potential duplicates with different IDs

## Database Schema
The scripts work with the following tables:

### Vendors Table
- VendorID (PK)
- VendorName
- Country
- MaterialID (FK)
- ContactNumber
- Status

### Materials Table
- MaterialID (PK)
- MaterialDesc
- MaterialType
- UnitOfMeasure
- MaterialGroup
- Status
- CreatedDate
- Weight

## Usage Instructions

### 1. Identify Duplicate Material IDs
```sql
SELECT 
    MaterialID,
    COUNT(*) AS RecordCount
FROM Materials
GROUP BY MaterialID
HAVING COUNT(*) > 1
ORDER BY RecordCount DESC;
```

### 2. Examine the Duplicate Records in Detail
```sql
WITH DuplicateMaterials AS (
    SELECT MaterialID
    FROM Materials
    GROUP BY MaterialID
    HAVING COUNT(*) > 1
)
SELECT m.*
FROM Materials m
INNER JOIN DuplicateMaterials d ON m.MaterialID = d.MaterialID
ORDER BY m.MaterialID;
```

### 3. Resolution Strategy
Execute the scripts in `resolution_strategy.sql` to consolidate duplicate records. Review results before committing changes.

## Implementation Approach

### Phase 1: Analysis
1. Run identification scripts to understand the scope of duplicate issues
2. Generate reports of inconsistencies
3. Document business rules for resolution

### Phase 2: Planning
1. Define consolidation rules (which records take precedence)
2. Set up backup tables before making changes
3. Define validation criteria for successful resolution

### Phase 3: Implementation
1. Execute resolution scripts in a development environment
2. Validate results against defined criteria
3. Document any manual resolutions needed

### Phase 4: Production Deployment
1. Schedule maintenance window
2. Execute scripts with transaction protection
3. Verify system integrity after changes

## Best Practices
- Always back up data before running resolution scripts
- Use transactions to ensure atomicity of operations
- Test in a development environment first
- Document all changes and decisions
- Implement preventive measures to avoid future duplicates

## Preventive Measures
To prevent future duplicate issues:
- Add uniqueness constraints to appropriate columns
- Implement validation triggers
- Create standardized data entry procedures
- Consider implementing a master data management system

## Contributors
- [Your Name]
- [Team Member 1]
- [Team Member 2]

## License
[Specify License]

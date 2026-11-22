# NOTES - BidNile
 
## 1. Four schemas and their tables
- **Operations** - Country, City, Warehouse, Employee: where BidNile physically works and who works there.
- **Membership** - Member, Wallet: people and their money.
- **Catalog** - Category, Item, ItemPhoto: what is being sold.
- **Trade** - Auction, Bid, AuctionFollow: selling and bidding activity. (`AuctionFollow` later moves to **Marketing**, task 3.12.)
Each schema is one business area, so a team could own a schema (Marketing took one).
 
## 2. Relationship types and where they are in BidNile
- **1:1** - Member - Wallet (`Wallet.MemberId` is UNIQUE); Employee is a Member (`Employee.MemberId` is both PK and FK).
- **1:N** - Country - City, City - Member, Warehouse - Employee, Item - Auction, Auction - Bid, Category - Item ...
- **M:N** - Member - Auction ("follows"), resolved by `AuctionFollow` with composite PK (MemberId, AuctionId).
- **Recursive** - Member invites Member (`InvitedByMemberId`); Category tree (`ParentCategoryId`).
- **Circular** - Employee works in a Warehouse, and a Warehouse is managed by an Employee.
- **Weak entity** - `ItemPhoto`: identified only by (ItemId, PhotoNo) and deleted with its item (On Delete Cascade).

## 3. Data type choices
- **GUID for members**: the phone creates the id before the server sees the request, so it must be globally unique without asking the server; running numbers would collide and be guessable.
- **BIGINT for bids**: the counter will pass 2.1 billion, the maximum of INT (2,147,483,647).
- **FLOAT for GPS**: coordinates are approximate measurements, so an approximate type is fine and the range is easy to check.
- **DECIMAL for money**: exact values; FLOAT can drift (0.1 + 0.2 is not exactly 0.3).
- **DATETIMEOFFSET for auctions**: members are in Cairo (+02:00), Riyadh (+03:00), Dubai (+04:00); the offset is stored, so an end time is one unambiguous moment.

## 4. Why the circular relationship cannot be created inside CREATE TABLE
Whichever table is created first would reference a table that does not exist yet (Employee needs Warehouse, Warehouse needs Employee). So both tables are created without that FK, and `FK_Warehouse_Employee` is added afterwards with ALTER TABLE (3.1). The manager column is also nullable, so a warehouse can exist before its manager.

## 6. The errors in 3.6 and 3.11
- **3.4 / 3.6 (`Capacity` -> `MaxItems`)**: renaming the column failed with
  *"Object 'Operations.Warehouse.Capacity' cannot be renamed because the object participates in enforced dependencies"* (Msg 15336).
  Later, `ALTER COLUMN MaxItems SMALLINT` failed with
  *"The object 'CK_Warehouse_MaxItems' is dependent on column 'MaxItems'"* (Msg 5074 / 4922).
  Cause: the CHECK constraint (`> 0`) is attached to the column, so SQL Server blocks renaming or changing its type.
  Fix: drop the CHECK, do the rename / type change, then add the CHECK again (still `> 0`, and in 3.6 also `<= 30000`).

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
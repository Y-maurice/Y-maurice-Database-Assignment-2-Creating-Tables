USE master;
GO
IF DB_ID(N'BidNile') IS NOT NULL
BEGIN
    ALTER DATABASE BidNile SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BidNile;
END
GO

CREATE DATABASE BidNile;
GO
USE BidNile;
GO

/* ---------------------------------------------------------------------
   Task 1.3 => 4 schemas
   Operations : Country, City, Warehouse, Employee
   Membership : Member, Wallet
   Catalog    : Category, Item, ItemPhoto
   Trade      : Auction, Bid, AuctionFollow
   --------------------------------------------------------------------- */
CREATE SCHEMA Operations;
GO
CREATE SCHEMA Membership;
GO
CREATE SCHEMA Catalog;
GO
CREATE SCHEMA Trade;
GO

/* =====================================================================
   TASK 2 - CREATE TABLE
   ===================================================================== */

-- Operations
CREATE TABLE Operations.Country
(
    CountryCode CHAR(2)       NOT NULL
        CONSTRAINT PK_Country PRIMARY KEY,
    NameEn      VARCHAR(60)   NOT NULL
        CONSTRAINT UQ_Country_NameEn UNIQUE,
    NameAr      NVARCHAR(60)  NOT NULL,
    PhoneCode   VARCHAR(5)    NOT NULL
        CONSTRAINT CK_Country_PhoneCode CHECK (PhoneCode LIKE '+[0-9]%'),
    CONSTRAINT CK_Country_CountryCode CHECK (CountryCode LIKE '[A-Z][A-Z]')
);
GO

CREATE TABLE Operations.City
(
    CityId      INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_City PRIMARY KEY,
    CountryCode CHAR(2)       NOT NULL,                    
    Name        NVARCHAR(60)  NOT NULL,
    CONSTRAINT UQ_City_CountryCode_Name UNIQUE (CountryCode, Name)   -- composite UNIQUE
);
GO

CREATE TABLE Operations.Warehouse
(
    WarehouseId     INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Warehouse PRIMARY KEY,
    Name            NVARCHAR(80)  NOT NULL
        CONSTRAINT UQ_Warehouse_Name UNIQUE,
    Capacity        INT           NOT NULL
        CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
    CityId          INT           NOT NULL,                
    Latitude        FLOAT         NOT NULL
        CONSTRAINT CK_Warehouse_Latitude  CHECK (Latitude  BETWEEN -90  AND 90),
    Longitude       FLOAT         NOT NULL
        CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    ManagerMemberId UNIQUEIDENTIFIER NULL,                  
    ManagerSince    DATE          NULL,
    CONSTRAINT CK_Warehouse_Manager CHECK
        (   (ManagerMemberId IS NULL     AND ManagerSince IS NULL)
         OR (ManagerMemberId IS NOT NULL AND ManagerSince IS NOT NULL))
);
GO
-- A person manages at most ONE warehouse. A plain UNIQUE constraint would allow only
-- one NULL manager, so it is a filtered unique index (still named UQ_).
CREATE UNIQUE INDEX UQ_Warehouse_ManagerMemberId
    ON Operations.Warehouse (ManagerMemberId)
    WHERE ManagerMemberId IS NOT NULL;
GO

CREATE TABLE Operations.Employee
(
    MemberId    UNIQUEIDENTIFIER NOT NULL                  -- an employee IS a member 
        CONSTRAINT PK_Employee PRIMARY KEY,
    WarehouseId INT           NOT NULL                     -- works in exactly one warehouse 
);
GO

-- ---------- Membership 
CREATE TABLE Membership.Member
(
    MemberId          UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_Member_MemberId DEFAULT NEWID()
        CONSTRAINT PK_Member PRIMARY KEY,
    FullName          NVARCHAR(100) NOT NULL,
    Email             VARCHAR(254)  NOT NULL
        CONSTRAINT UQ_Member_Email UNIQUE
        CONSTRAINT CK_Member_Email CHECK (Email LIKE '%_@_%._%'),
    Mobile            VARCHAR(16)   NOT NULL
        CONSTRAINT CK_Member_Mobile CHECK (Mobile LIKE '+[0-9]%'),
    NationalId        VARCHAR(20)   NOT NULL
        CONSTRAINT UQ_Member_NationalId UNIQUE
        CONSTRAINT CK_Member_NationalId CHECK (NationalId NOT LIKE '%[^A-Za-z0-9]%'),
    BirthDate         DATE          NOT NULL
        CONSTRAINT CK_Member_BirthDate CHECK (BirthDate <= DATEADD(YEAR, -18, CAST(GETDATE() AS DATE))),  -- 18 or older
    IsVerified        BIT           NOT NULL
        CONSTRAINT DF_Member_IsVerified DEFAULT 0,
    RegisteredAt      DATETIME2(3)  NOT NULL
        CONSTRAINT DF_Member_RegisteredAt DEFAULT SYSDATETIME(),
    CityId            INT           NOT NULL,                
    InvitedByMemberId UNIQUEIDENTIFIER NULL,                 
    CONSTRAINT CK_Member_InvitedBy CHECK (InvitedByMemberId IS NULL OR InvitedByMemberId <> MemberId)
);
GO

CREATE TABLE Membership.Wallet
(
    WalletId    INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Wallet PRIMARY KEY,
    MemberId    UNIQUEIDENTIFIER NOT NULL                    -- 1:1 with Member 
        CONSTRAINT UQ_Wallet_MemberId UNIQUE,
    Balance     DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Wallet_Balance DEFAULT 0
        CONSTRAINT CK_Wallet_Balance CHECK (Balance >= 0),
    HeldAmount  DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Wallet_HeldAmount DEFAULT 0
        CONSTRAINT CK_Wallet_HeldAmount CHECK (HeldAmount >= 0),
    Currency    CHAR(3)       NOT NULL
        CONSTRAINT DF_Wallet_Currency DEFAULT 'EGP'
        CONSTRAINT CK_Wallet_Currency CHECK (Currency LIKE '[A-Z][A-Z][A-Z]'),
    UpdatedAt   DATETIME2(3)  NOT NULL
        CONSTRAINT DF_Wallet_UpdatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Wallet_HeldWithinBalance CHECK (HeldAmount <= Balance)   -- table-level CHECK
);
GO

-- ---------- Catalog ---------------------------------------------------
CREATE TABLE Catalog.Category
(
    CategoryId       INT NOT NULL                            -- NO identity: the business chooses 100, 110, 200 
        CONSTRAINT PK_Category PRIMARY KEY,
    ParentCategoryId INT NULL,                              
    NameEn           VARCHAR(50)  NOT NULL
        CONSTRAINT UQ_Category_NameEn UNIQUE,
    NameAr           NVARCHAR(50) NULL,
    CommissionPct    DECIMAL(4,2) NOT NULL
        CONSTRAINT CK_Category_CommissionPct CHECK (CommissionPct BETWEEN 0 AND 30),
    CONSTRAINT CK_Category_ParentCategoryId CHECK (ParentCategoryId IS NULL OR ParentCategoryId <> CategoryId)
);
GO

CREATE TABLE Catalog.Item
(
    ItemId            INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Item PRIMARY KEY,
    SellerMemberId    UNIQUEIDENTIFIER NOT NULL,             
    CategoryId        INT           NOT NULL,                
    WarehouseId       INT           NOT NULL,                
    Title             NVARCHAR(150) NOT NULL,
    Description       NVARCHAR(MAX) NULL,
    ConditionScore    TINYINT       NOT NULL
        CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
    Specs             NVARCHAR(MAX) NOT NULL                 -- one JSON document per item
        CONSTRAINT CK_Item_Specs CHECK (ISJSON(Specs) = 1),
    InspectorMemberId UNIQUEIDENTIFIER NULL,                 -- the employee who inspected it 
    InspectedAt       DATETIME2(0)  NULL,
    ListedAt          DATETIME2(0)  NOT NULL
        CONSTRAINT DF_Item_ListedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Item_Inspection CHECK
        (   (InspectorMemberId IS NULL     AND InspectedAt IS NULL)
         OR (InspectorMemberId IS NOT NULL AND InspectedAt IS NOT NULL)),
    CONSTRAINT CK_Item_InspectorNotSeller CHECK (InspectorMemberId IS NULL OR InspectorMemberId <> SellerMemberId)
);
GO

CREATE TABLE Catalog.ItemPhoto                               -- weak entity: identified by item + number
(
    ItemId   INT           NOT NULL,                         -- FK in 3.1 (ON DELETE CASCADE)
    PhotoNo  TINYINT       NOT NULL
        CONSTRAINT CK_ItemPhoto_PhotoNo CHECK (PhotoNo BETWEEN 1 AND 20),
    Url      VARCHAR(500)  NOT NULL,
    IsMain   BIT           NOT NULL
        CONSTRAINT DF_ItemPhoto_IsMain DEFAULT 0,
    CONSTRAINT PK_ItemPhoto PRIMARY KEY (ItemId, PhotoNo)    -- composite PK
);
GO

-- ---------- Trade 
CREATE TABLE Trade.Auction
(
    AuctionId    INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Auction PRIMARY KEY,
    ItemId       INT              NOT NULL,                 
    StartPrice   DECIMAL(12,2)    NOT NULL
        CONSTRAINT CK_Auction_StartPrice CHECK (StartPrice > 0),
    ReservePrice DECIMAL(12,2)    NULL,
    BidIncrement DECIMAL(12,2)    NOT NULL
        CONSTRAINT DF_Auction_BidIncrement DEFAULT 50.00
        CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0),
    StartsAt     DATETIMEOFFSET(0) NOT NULL,                 -- keeps the +02:00 / +03:00 / +04:00 offset
    EndsAt       DATETIMEOFFSET(0) NOT NULL,
    Status       VARCHAR(20)      NOT NULL                   -- 20 chars so 'PendingReview' (13) fits in 3.8
        CONSTRAINT DF_Auction_Status DEFAULT 'Draft'
        CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled')),
    CONSTRAINT CK_Auction_Dates   CHECK (EndsAt > StartsAt),
    CONSTRAINT CK_Auction_ReservePrice CHECK (ReservePrice IS NULL OR ReservePrice >= StartPrice)
);
GO

CREATE TABLE Trade.Bid
(
    BidId      BIGINT IDENTITY(1,1) NOT NULL                 -- counter will pass 2.1 billion
        CONSTRAINT PK_Bid PRIMARY KEY,
    AuctionId  INT            NOT NULL,                      
    MemberId   UNIQUEIDENTIFIER NOT NULL,                    
    Amount     DECIMAL(12,2)  NOT NULL
        CONSTRAINT CK_Bid_Amount CHECK (Amount > 0),
    PlacedAt   DATETIME2(3)   NOT NULL                       -- to the millisecond
        CONSTRAINT DF_Bid_PlacedAt DEFAULT SYSDATETIME(),
    IpAddress  VARCHAR(45)    NOT NULL,                      -- IPv4 or IPv6
    CONSTRAINT UQ_Bid_AuctionId_Amount UNIQUE (AuctionId, Amount)   -- no two equal bids in one auction
);
GO

CREATE TABLE Trade.AuctionFollow                             -- M:N between Member and Auction
(
    MemberId    UNIQUEIDENTIFIER NOT NULL,                  
    AuctionId   INT            NOT NULL,                     
    FollowedAt  DATETIME2(0)   NOT NULL
        CONSTRAINT DF_AuctionFollow_FollowedAt DEFAULT SYSDATETIME(),
    CONSTRAINT PK_AuctionFollow PRIMARY KEY (MemberId, AuctionId)   -- nobody follows twice
);
GO


/* =====================================================================
   TASK 3 - ALTER  
   ===================================================================== */

-- 3.1 Connect everything. Only Item -> ItemPhoto cascades; all other FKs = NO ACTION.

ALTER TABLE Operations.City
    ADD CONSTRAINT FK_City_Country FOREIGN KEY (CountryCode) REFERENCES Operations.Country (CountryCode);

ALTER TABLE Operations.Warehouse
    ADD CONSTRAINT FK_Warehouse_City FOREIGN KEY (CityId) REFERENCES Operations.City (CityId);

ALTER TABLE Operations.Employee
    ADD CONSTRAINT FK_Employee_Member FOREIGN KEY (MemberId) REFERENCES Membership.Member (MemberId);

ALTER TABLE Operations.Employee
    ADD CONSTRAINT FK_Employee_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Operations.Warehouse (WarehouseId);
--(closes the circle Warehouse <-> Employee)
ALTER TABLE Operations.Warehouse
    ADD CONSTRAINT FK_Warehouse_Employee FOREIGN KEY (ManagerMemberId) REFERENCES Operations.Employee (MemberId);

ALTER TABLE Membership.Member
    ADD CONSTRAINT FK_Member_City FOREIGN KEY (CityId) REFERENCES Operations.City (CityId);
--  (recursive: who invited whom)
ALTER TABLE Membership.Member
    ADD CONSTRAINT FK_Member_Member FOREIGN KEY (InvitedByMemberId) REFERENCES Membership.Member (MemberId);
-- 3.1
ALTER TABLE Membership.Wallet
    ADD CONSTRAINT FK_Wallet_Member FOREIGN KEY (MemberId) REFERENCES Membership.Member (MemberId);
-- (recursive: category tree)
ALTER TABLE Catalog.Category
    ADD CONSTRAINT FK_Category_Category FOREIGN KEY (ParentCategoryId) REFERENCES Catalog.Category (CategoryId);
--  (seller)
ALTER TABLE Catalog.Item
    ADD CONSTRAINT FK_Item_Member FOREIGN KEY (SellerMemberId) REFERENCES Membership.Member (MemberId);

ALTER TABLE Catalog.Item
    ADD CONSTRAINT FK_Item_Category FOREIGN KEY (CategoryId) REFERENCES Catalog.Category (CategoryId);

ALTER TABLE Catalog.Item
    ADD CONSTRAINT FK_Item_Warehouse FOREIGN KEY (WarehouseId) REFERENCES Operations.Warehouse (WarehouseId);
--(inspector)
ALTER TABLE Catalog.Item
    ADD CONSTRAINT FK_Item_Employee FOREIGN KEY (InspectorMemberId) REFERENCES Operations.Employee (MemberId);
-- (deleting an item deletes its photos)
ALTER TABLE Catalog.ItemPhoto
    ADD CONSTRAINT FK_ItemPhoto_Item FOREIGN KEY (ItemId) REFERENCES Catalog.Item (ItemId) ON DELETE CASCADE;

ALTER TABLE Trade.Auction
    ADD CONSTRAINT FK_Auction_Item FOREIGN KEY (ItemId) REFERENCES Catalog.Item (ItemId);

ALTER TABLE Trade.Bid
    ADD CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES Trade.Auction (AuctionId);

ALTER TABLE Trade.Bid
    ADD CONSTRAINT FK_Bid_Member FOREIGN KEY (MemberId) REFERENCES Membership.Member (MemberId);

ALTER TABLE Trade.AuctionFollow
    ADD CONSTRAINT FK_AuctionFollow_Member FOREIGN KEY (MemberId) REFERENCES Membership.Member (MemberId);

ALTER TABLE Trade.AuctionFollow
    ADD CONSTRAINT FK_AuctionFollow_Auction FOREIGN KEY (AuctionId) REFERENCES Trade.Auction (AuctionId);
GO

-- 3.2 App language: NOT NULL column in ONE statement; existing members get 'ar' from the DEFAULT.
-- 3.2
ALTER TABLE Membership.Member
    ADD AppLanguage CHAR(2) NOT NULL
        CONSTRAINT DF_Member_AppLanguage DEFAULT 'ar'
        CONSTRAINT CK_Member_AppLanguage CHECK (AppLanguage IN ('ar', 'en'));
GO

-- 3.3 Featured items: NOT NULL Yes/No, default No (existing items become 0).
-- 3.3
ALTER TABLE Catalog.Item
    ADD IsFeatured BIT NOT NULL
        CONSTRAINT DF_Item_IsFeatured DEFAULT 0;
GO

-- 3.4 Naming review. Columns are renamed with sp_rename (not ALTER TABLE).
-- 3.4
EXEC sp_rename N'Trade.Bid.IpAddress', N'DeviceIp', N'COLUMN';
GO
-- 3.4  The CHECK on Capacity blocks the rename (Msg 15336), so: drop it, rename, re-create it under the new name.
ALTER TABLE Operations.Warehouse DROP CONSTRAINT CK_Warehouse_Capacity;
GO
-- 3.4
EXEC sp_rename N'Operations.Warehouse.Capacity', N'MaxItems', N'COLUMN';
GO
-- 3.4
ALTER TABLE Operations.Warehouse ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0);
GO

-- 3.5 Longer names. Re-state NOT NULL, otherwise ALTER COLUMN would make the column nullable.
-- 3.5
ALTER TABLE Membership.Member ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO

-- 3.6 No warehouse holds more than 30,000 items -> SMALLINT (max 32,767) is the smallest type that fits.
-- First attempt fails: "The object 'CK_Warehouse_MaxItems' is dependent on column 'MaxItems'".
-- Cause: a CHECK depends on the column. Fix: drop it, change the type, re-create it (keeping "> 0").
-- 3.6
ALTER TABLE Operations.Warehouse DROP CONSTRAINT CK_Warehouse_MaxItems;
GO
-- 3.6
ALTER TABLE Operations.Warehouse ALTER COLUMN MaxItems SMALLINT NOT NULL;
GO
-- 3.6
ALTER TABLE Operations.Warehouse
    ADD CONSTRAINT CK_Warehouse_MaxItems CHECK (MaxItems > 0 AND MaxItems <= 30000);
GO

-- 3.7 Maximum commission is now 25 %.
-- 3.7
ALTER TABLE Catalog.Category DROP CONSTRAINT CK_Category_CommissionPct;
GO
-- 3.7
ALTER TABLE Catalog.Category
    ADD CONSTRAINT CK_Category_CommissionPct CHECK (CommissionPct BETWEEN 0 AND 25);
GO

-- 3.8 Auctions must be reviewed first: allow 'PendingReview' and make it the new default.
-- 3.8
ALTER TABLE Trade.Auction DROP CONSTRAINT CK_Auction_Status;
GO
-- 3.8
ALTER TABLE Trade.Auction DROP CONSTRAINT DF_Auction_Status;
GO
-- 3.8
ALTER TABLE Trade.Auction
    ADD CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'PendingReview', 'Live', 'Ended', 'Cancelled'));
GO
-- 3.8
ALTER TABLE Trade.Auction
    ADD CONSTRAINT DF_Auction_Status DEFAULT 'PendingReview' FOR Status;
GO

-- 3.9 Optional "Buy Now" price, always above the starting price.
-- 3.9
ALTER TABLE Trade.Auction ADD BuyNowPrice DECIMAL(12,2) NULL;
GO
-- 3.9  WITH CHECK (not NOCHECK): the table already has rows, and WITH CHECK validates them
--      against the new rule (all existing BuyNowPrice are NULL, so they pass). The constraint then
--      stays "trusted", which the optimizer can use. NOCHECK would skip the validation and leave the
--      constraint untrusted - only acceptable when you knowingly keep bad legacy rows.
-- 3.9
ALTER TABLE Trade.Auction WITH CHECK
    ADD CONSTRAINT CK_Auction_BuyNowPrice CHECK (BuyNowPrice IS NULL OR BuyNowPrice > StartPrice);
GO

-- 3.10 Duplicate accounts were found: the mobile number must be unique.
-- 3.10
ALTER TABLE Membership.Member
    ADD CONSTRAINT UQ_Member_Mobile UNIQUE (Mobile);
GO

-- 3.11 We need WHEN a member was verified (optional), then drop the Yes/No column.
-- 3.11
ALTER TABLE Membership.Member ADD VerifiedAt DATETIME2(0) NULL;
GO
UPDATE Membership.Member SET VerifiedAt = RegisteredAt WHERE IsVerified = 1;
GO
-- First attempt fails: "The object 'DF_Member_IsVerified' is dependent on column 'IsVerified'".
-- Cause: the DEFAULT constraint is attached to the column => Fix: drop the default first, then the column.
-- 3.11
ALTER TABLE Membership.Member DROP CONSTRAINT DF_Member_IsVerified;
GO
-- 3.11
ALTER TABLE Membership.Member DROP COLUMN IsVerified;
GO

-- 3.12 Marketing now owns engagement data: new schema, then move the "followed auctions" table.
-- 3.12
CREATE SCHEMA Marketing;
GO
-- 3.12
ALTER SCHEMA Marketing TRANSFER Trade.AuctionFollow;
GO
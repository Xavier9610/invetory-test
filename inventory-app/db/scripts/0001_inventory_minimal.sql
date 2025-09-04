-- InventoryDB (Minimal) - SQL Server
-- Tables: Product, TransactionType, InventoryTransaction
-- Stored Procedures: Add/Update/Delete/List Products
-- Stock is auto-adjusted via triggers on InventoryTransaction

IF DB_ID('InventoryDB') IS NULL
BEGIN
    CREATE DATABASE InventoryDB;
END
GO
USE InventoryDB;
GO

/* ==== Required SET options for computed columns / persisted / indexed views ==== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

/* =====================
   tabla: TransactionType
   1 = Purchase (+1), 2 = Sale (-1)
   ===================== */
IF OBJECT_ID('dbo.TransactionType','U') IS NOT NULL DROP TABLE dbo.TransactionType;
GO
CREATE TABLE dbo.TransactionType
(
    TransactionTypeId  TINYINT      NOT NULL CONSTRAINT PK_TransactionType PRIMARY KEY,
    Name               NVARCHAR(20) NOT NULL CONSTRAINT UQ_TransactionType_Name UNIQUE,
    Effect             SMALLINT     NOT NULL CONSTRAINT CK_TransactionType_Effect CHECK (Effect IN (-1,1))
);
GO
IF NOT EXISTS (SELECT 1 FROM dbo.TransactionType)
BEGIN
    INSERT INTO dbo.TransactionType(TransactionTypeId, Name, Effect)
    VALUES (1, N'Purchase', +1),
           (2, N'Sale',     -1);
END
GO

/* =====================
   tabla: Product
   ===================== */
IF OBJECT_ID('dbo.Product','U') IS NOT NULL DROP TABLE dbo.Product;
GO
CREATE TABLE dbo.Product
(
    ProductId   INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
    Name        NVARCHAR(200)      NOT NULL,
    Description NVARCHAR(MAX)      NULL,
    ImageUrl    NVARCHAR(512)      NULL,
    Price       DECIMAL(18,2)      NOT NULL CONSTRAINT CK_Product_Price CHECK (Price >= 0),
    Stock       INT                NOT NULL CONSTRAINT DF_Product_Stock DEFAULT (0) CONSTRAINT CK_Product_Stock CHECK (Stock >= 0),
    IsActive    BIT                NOT NULL CONSTRAINT DF_Product_IsActive DEFAULT(1),
    CreatedAt   DATETIME2(3)       NOT NULL CONSTRAINT DF_Product_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt   DATETIME2(3)       NOT NULL CONSTRAINT DF_Product_UpdatedAt DEFAULT SYSUTCDATETIME(),
    RowVersion  ROWVERSION         NOT NULL
);
GO
--CREATE INDEX IX_Product_Name     ON dbo.Product(Name);
--REATE INDEX IX_Product_IsActive ON dbo.Product(IsActive) INCLUDE (Name, Price, Stock);
GO

/* =====================
   InventoryTransaction
   ===================== */
IF OBJECT_ID('dbo.InventoryTransaction','U') IS NOT NULL DROP TABLE dbo.InventoryTransaction;
GO
CREATE TABLE dbo.InventoryTransaction
(
    InventoryTransactionId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventoryTransaction PRIMARY KEY,
    OccurredAt             DATETIME2(3)         NOT NULL CONSTRAINT DF_InvTrx_OccurredAt DEFAULT SYSUTCDATETIME(),
    TransactionTypeId      TINYINT              NOT NULL,
    ProductId              INT                  NOT NULL,
    Quantity               INT                  NOT NULL CONSTRAINT CK_InvTrx_Qty CHECK (Quantity > 0),
    UnitPrice              DECIMAL(18,2)        NOT NULL CONSTRAINT CK_InvTrx_UnitPrice CHECK (UnitPrice >= 0),
    TotalPrice             AS (CONVERT(DECIMAL(18,2), UnitPrice * Quantity)) PERSISTED,
    Detail                 NVARCHAR(500)        NULL,
    CreatedAt              DATETIME2(3)         NOT NULL CONSTRAINT DF_InvTrx_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt              DATETIME2(3)         NOT NULL CONSTRAINT DF_InvTrx_UpdatedAt DEFAULT SYSUTCDATETIME(),
    RowVersion             ROWVERSION           NOT NULL,
    CONSTRAINT FK_InvTrx_Type    FOREIGN KEY (TransactionTypeId) REFERENCES dbo.TransactionType(TransactionTypeId),
    CONSTRAINT FK_InvTrx_Product FOREIGN KEY (ProductId)         REFERENCES dbo.Product(ProductId)
);
GO
--REATE INDEX IX_InvTrx_Product_Date ON dbo.InventoryTransaction(ProductId, OccurredAt DESC)
--    INCLUDE (TransactionTypeId, Quantity, UnitPrice, TotalPrice);
GO

/* =====================
   TRIGGERS: auto-adjust stock and validate no oversell
   ===================== */
IF OBJECT_ID('dbo.trg_InvTrx_IOI','TR') IS NOT NULL DROP TRIGGER dbo.trg_InvTrx_IOI;
GO
CREATE TRIGGER dbo.trg_InvTrx_IOI ON dbo.InventoryTransaction
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    CREATE TABLE #Delta(ProductId INT PRIMARY KEY, Delta INT NOT NULL);

    INSERT INTO #Delta(ProductId, Delta)
    SELECT i.ProductId, SUM(i.Quantity * tt.Effect)
    FROM inserted i
    JOIN dbo.TransactionType tt ON tt.TransactionTypeId = i.TransactionTypeId
    GROUP BY i.ProductId;

    -- Validate no negative stock after applying deltas
    IF EXISTS (
        SELECT 1
        FROM #Delta d
        JOIN dbo.Product p WITH (ROWLOCK, UPDLOCK, HOLDLOCK) ON p.ProductId = d.ProductId
        WHERE (p.Stock + d.Delta) < 0
    )
    BEGIN
        RAISERROR('Insufficient stock for one or more products.', 16, 1);
        ROLLBACK TRANSACTION; RETURN;
    END

    INSERT INTO dbo.InventoryTransaction(OccurredAt, TransactionTypeId, ProductId, Quantity, UnitPrice, Detail)
    SELECT ISNULL(i.OccurredAt, SYSUTCDATETIME()), i.TransactionTypeId, i.ProductId, i.Quantity, i.UnitPrice, i.Detail
    FROM inserted i;

    UPDATE p
    SET p.Stock = p.Stock + d.Delta,
        p.UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Product p
    JOIN #Delta d ON d.ProductId = p.ProductId;
END
GO

IF OBJECT_ID('dbo.trg_InvTrx_IOU','TR') IS NOT NULL DROP TRIGGER dbo.trg_InvTrx_IOU;
GO
CREATE TRIGGER dbo.trg_InvTrx_IOU ON dbo.InventoryTransaction
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    CREATE TABLE #Work(ProductId INT NOT NULL, DeltaPart INT NOT NULL);
    CREATE TABLE #Delta(ProductId INT PRIMARY KEY, Delta INT NOT NULL);

    INSERT INTO #Work(ProductId, DeltaPart)
    SELECT d.ProductId, - (d.Quantity * tt.Effect)
    FROM deleted d
    JOIN dbo.TransactionType tt ON tt.TransactionTypeId = d.TransactionTypeId;

    INSERT INTO #Work(ProductId, DeltaPart)
    SELECT i.ProductId, (i.Quantity * tt.Effect)
    FROM inserted i
    JOIN dbo.TransactionType tt ON tt.TransactionTypeId = i.TransactionTypeId;

    INSERT INTO #Delta(ProductId, Delta)
    SELECT ProductId, SUM(DeltaPart)
    FROM #Work GROUP BY ProductId;

    IF EXISTS (
        SELECT 1
        FROM #Delta d
        JOIN dbo.Product p WITH (ROWLOCK, UPDLOCK, HOLDLOCK) ON p.ProductId = d.ProductId
        WHERE (p.Stock + d.Delta) < 0
    )
    BEGIN
        RAISERROR('Insufficient stock after update.', 16, 1);
        ROLLBACK TRANSACTION; RETURN;
    END

    UPDATE t
    SET  OccurredAt = COALESCE(i.OccurredAt, t.OccurredAt),
         TransactionTypeId = i.TransactionTypeId,
         ProductId = i.ProductId,
         Quantity = i.Quantity,
         UnitPrice = i.UnitPrice,
         Detail = i.Detail,
         UpdatedAt = SYSUTCDATETIME()
    FROM dbo.InventoryTransaction t
    JOIN inserted i ON i.InventoryTransactionId = t.InventoryTransactionId;

    UPDATE p
    SET p.Stock = p.Stock + d.Delta,
        p.UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Product p
    JOIN #Delta d ON d.ProductId = p.ProductId;
END
GO

IF OBJECT_ID('dbo.trg_InvTrx_IOD','TR') IS NOT NULL DROP TRIGGER dbo.trg_InvTrx_IOD;
GO
CREATE TRIGGER dbo.trg_InvTrx_IOD ON dbo.InventoryTransaction
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    CREATE TABLE #Delta(ProductId INT PRIMARY KEY, Delta INT NOT NULL);

    INSERT INTO #Delta(ProductId, Delta)
    SELECT d.ProductId, SUM(-1 * d.Quantity * tt.Effect)
    FROM deleted d
    JOIN dbo.TransactionType tt ON tt.TransactionTypeId = d.TransactionTypeId
    GROUP BY d.ProductId;

    IF EXISTS (
        SELECT 1
        FROM #Delta d
        JOIN dbo.Product p WITH (ROWLOCK, UPDLOCK, HOLDLOCK) ON p.ProductId = d.ProductId
        WHERE (p.Stock + d.Delta) < 0
    )
    BEGIN
        RAISERROR('Delete would cause negative stock.', 16, 1);
        ROLLBACK TRANSACTION; RETURN;
    END

    DELETE t FROM dbo.InventoryTransaction t
    JOIN deleted d ON d.InventoryTransactionId = t.InventoryTransactionId;

    UPDATE p
    SET p.Stock = p.Stock + d.Delta,
        p.UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Product p
    JOIN #Delta d ON d.ProductId = p.ProductId;
END
GO

/* =====================
   STORED PROCEDURES (minimal CRUD for Product)
   ===================== */
IF OBJECT_ID('dbo.usp_Product_Add','P') IS NOT NULL DROP PROCEDURE dbo.usp_Product_Add;
GO
CREATE PROCEDURE dbo.usp_Product_Add
    @Name        NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @ImageUrl    NVARCHAR(512) = NULL,
    @Price       DECIMAL(18,2),
    @InitialStock INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Price < 0 OR @InitialStock < 0
    BEGIN
        RAISERROR('Price and InitialStock must be non-negative.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.Product(Name, Description, ImageUrl, Price, Stock)
    VALUES(@Name, @Description, @ImageUrl, @Price, @InitialStock);

    SELECT SCOPE_IDENTITY() AS ProductId;
END
GO

IF OBJECT_ID('dbo.usp_Product_Update','P') IS NOT NULL DROP PROCEDURE dbo.usp_Product_Update;
GO
CREATE PROCEDURE dbo.usp_Product_Update
    @ProductId   INT,
    @Name        NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @ImageUrl    NVARCHAR(512) = NULL,
    @Price       DECIMAL(18,2),
    @IsActive    BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Price < 0
    BEGIN
        RAISERROR('Price must be non-negative.', 16, 1);
        RETURN;
    END

    UPDATE dbo.Product
    SET Name = @Name,
        Description = @Description,
        ImageUrl = @ImageUrl,
        Price = @Price,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME()
    WHERE ProductId = @ProductId;

    IF @@ROWCOUNT = 0 RAISERROR('Product not found.', 16, 1);
END
GO

IF OBJECT_ID('dbo.usp_Product_Delete','P') IS NOT NULL DROP PROCEDURE dbo.usp_Product_Delete;
GO
CREATE PROCEDURE dbo.usp_Product_Delete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Minimal safe rule: do not allow delete if there are transactions
    IF EXISTS (SELECT 1 FROM dbo.InventoryTransaction WHERE ProductId = @ProductId)
    BEGIN
        RAISERROR('Cannot delete: product has transactions. Consider disabling (IsActive=0).', 16, 1);
        RETURN;
    END

    DELETE FROM dbo.Product WHERE ProductId = @ProductId;
    IF @@ROWCOUNT = 0 RAISERROR('Product not found.', 16, 1);
END
GO

IF OBJECT_ID('dbo.usp_Products_ListInventory','P') IS NOT NULL DROP PROCEDURE dbo.usp_Products_ListInventory;
GO
CREATE PROCEDURE dbo.usp_Products_ListInventory
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.ProductId,
           p.Name,
           p.Price,
           p.Description,
           p.Stock,
           p.ImageUrl,
           p.IsActive,
           p.CreatedAt,
           p.UpdatedAt
    FROM dbo.Product p
    ORDER BY p.Name;
END
GO

/* =====================
   Minimal seed & sanity checks (optional)
   ===================== */
-- Seed 2 products
IF NOT EXISTS (SELECT 1 FROM dbo.Product)
BEGIN
    EXEC dbo.usp_Product_Add @Name=N'USB Keyboard', @Description=N'Basic keyboard', @Price=18.50, @InitialStock=10;
    EXEC dbo.usp_Product_Add @Name=N'Wireless Mouse', @Description=N'2.4Ghz mouse', @Price=22.00, @InitialStock=5;
END
GO

-- Example purchase (+stock)
-- INSERT INTO dbo.InventoryTransaction(TransactionTypeId, ProductId, Quantity, UnitPrice, Detail)
-- VALUES(1, 1, 20, 12.00, N'Purchase batch');

-- Example sale (-stock)
-- INSERT INTO dbo.InventoryTransaction(TransactionTypeId, ProductId, Quantity, UnitPrice, Detail)
-- VALUES(2, 1, 3, 18.50, N'Sale batch');

-- Oversell test (should error)
-- INSERT INTO dbo.InventoryTransaction(TransactionTypeId, ProductId, Quantity, UnitPrice, Detail)
-- VALUES(2, 2, 999, 22.00, N'Oversell test');

-- List inventory
-- EXEC dbo.usp_Products_ListInventory;

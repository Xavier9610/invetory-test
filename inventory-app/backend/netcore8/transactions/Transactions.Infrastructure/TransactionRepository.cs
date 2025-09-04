using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Transactions.Application.Dtos;

namespace Transactions.Infrastructure;

public sealed class TransactionRepository : ITransactionRepository
{
    private readonly ISqlConnectionFactory _factory;

    public TransactionRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<long> AddAsync(TransactionCreateDto dto, CancellationToken ct)
    {
        using var con = _factory.Create();
        // Insert via plain SQL; triggers will validate stock and update Product.Stock
        var sql = @"
INSERT INTO dbo.InventoryTransaction(OccurredAt, TransactionTypeId, ProductId, Quantity, UnitPrice, Detail)
VALUES (ISNULL(@OccurredAt, SYSUTCDATETIME()), @TransactionTypeId, @ProductId, @Quantity, @UnitPrice, @Detail);
SELECT CAST(SCOPE_IDENTITY() AS BIGINT);";
        var id = await con.ExecuteScalarAsync<long>(new CommandDefinition(sql, dto, cancellationToken: ct));
        return id;
    }

    public async Task UpdateAsync(long id, TransactionUpdateDto dto, CancellationToken ct)
    {
        using var con = _factory.Create();
        var sql = @"
UPDATE dbo.InventoryTransaction
   SET OccurredAt = ISNULL(@OccurredAt, OccurredAt),
       TransactionTypeId = @TransactionTypeId,
       ProductId = @ProductId,
       Quantity = @Quantity,
       UnitPrice = @UnitPrice,
       Detail = @Detail,
       UpdatedAt = SYSUTCDATETIME()
 WHERE InventoryTransactionId = @Id;";
        var rows = await con.ExecuteAsync(new CommandDefinition(sql, new { Id = id, dto.TransactionTypeId, dto.ProductId, dto.Quantity, dto.UnitPrice, dto.Detail, dto.OccurredAt }, cancellationToken: ct));
        if (rows == 0) throw new InvalidOperationException("Transaction not found.");
    }

    public async Task DeleteAsync(long id, CancellationToken ct)
    {
        using var con = _factory.Create();
        var sql = @"DELETE FROM dbo.InventoryTransaction WHERE InventoryTransactionId = @Id;";
        var rows = await con.ExecuteAsync(new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));
        if (rows == 0) throw new InvalidOperationException("Transaction not found.");
    }

    public async Task<TransactionReadDto?> GetByIdAsync(long id, CancellationToken ct)
    {
        using var con = _factory.Create();
        var sql = @"
SELECT t.InventoryTransactionId, t.OccurredAt, t.TransactionTypeId, tt.Name AS TransactionType,
       t.ProductId, p.Name AS ProductName, t.Quantity, t.UnitPrice, t.TotalPrice, t.Detail
  FROM dbo.InventoryTransaction t
  JOIN dbo.TransactionType tt ON tt.TransactionTypeId = t.TransactionTypeId
  JOIN dbo.Product p ON p.ProductId = t.ProductId
 WHERE t.InventoryTransactionId = @Id;";
        return await con.QueryFirstOrDefaultAsync<TransactionReadDto>(new CommandDefinition(sql, new { Id = id }, cancellationToken: ct));
    }

    public async Task<PagedResult<TransactionReadDto>> SearchAsync(
        int? productId, byte? typeId, DateTime? startUtc, DateTime? endUtc,
        int page, int pageSize, CancellationToken ct)
    {
        using var con = _factory.Create();

        var where = @"WHERE ( @ProductId IS NULL OR t.ProductId = @ProductId )
                      AND   ( @TypeId    IS NULL OR t.TransactionTypeId = @TypeId )
                      AND   ( @StartUtc  IS NULL OR t.OccurredAt >= @StartUtc )
                      AND   ( @EndUtc    IS NULL OR t.OccurredAt <  @EndUtc )";

        var countSql = $@"SELECT COUNT(1)
                            FROM dbo.InventoryTransaction t
                            {where};";

        var dataSql = $@"
SELECT t.InventoryTransactionId, t.OccurredAt, t.TransactionTypeId, tt.Name AS TransactionType,
       t.ProductId, p.Name AS ProductName, t.Quantity, t.UnitPrice, t.TotalPrice, t.Detail
  FROM dbo.InventoryTransaction t
  JOIN dbo.TransactionType tt ON tt.TransactionTypeId = t.TransactionTypeId
  JOIN dbo.Product p ON p.ProductId = t.ProductId
  {where}
  ORDER BY t.OccurredAt DESC, t.InventoryTransactionId DESC
  OFFSET (@Offset) ROWS FETCH NEXT (@PageSize) ROWS ONLY;";

        var p = new DynamicParameters(new
        {
            ProductId = productId,
            TypeId = typeId,
            StartUtc = startUtc,
            EndUtc = endUtc,
            Offset = (page - 1) * pageSize,
            PageSize = pageSize
        });

        var total = await con.ExecuteScalarAsync<int>(new CommandDefinition(countSql, p, cancellationToken: ct));
        var items = (await con.QueryAsync<TransactionReadDto>(new CommandDefinition(dataSql, p, cancellationToken: ct))).ToList();

        return new PagedResult<TransactionReadDto> { Items = items, Total = total, Page = page, PageSize = pageSize };
    }
}

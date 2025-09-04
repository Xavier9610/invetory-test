using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Products.Application.Dtos;

namespace Products.Infrastructure;

public sealed class ProductRepository : IProductRepository
{
    private readonly ISqlConnectionFactory _factory;

    public ProductRepository(ISqlConnectionFactory factory) => _factory = factory;

    public async Task<int> AddAsync(ProductCreateDto dto, CancellationToken ct)
    {
        using var con = _factory.Create();
        var p = new DynamicParameters();
        p.Add("@Name", dto.Name, DbType.String);
        p.Add("@Description", dto.Description, DbType.String);
        p.Add("@ImageUrl", dto.ImageUrl, DbType.String);
        p.Add("@Price", dto.Price, DbType.Decimal);
        p.Add("@InitialStock", dto.InitialStock, DbType.Int32);
        // Stored proc returns SCOPE_IDENTITY() as ProductId
        var id = await con.ExecuteScalarAsync<decimal>(
            new CommandDefinition("dbo.usp_Product_Add", p, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        return (int)id;
    }

    public async Task UpdateAsync(int productId, ProductUpdateDto dto, CancellationToken ct)
    {
        using var con = _factory.Create();
        var p = new DynamicParameters();
        p.Add("@ProductId", productId, DbType.Int32);
        p.Add("@Name", dto.Name, DbType.String);
        p.Add("@Description", dto.Description, DbType.String);
        p.Add("@ImageUrl", dto.ImageUrl, DbType.String);
        p.Add("@Price", dto.Price, DbType.Decimal);
        p.Add("@IsActive", dto.IsActive, DbType.Boolean);

        await con.ExecuteAsync(new CommandDefinition(
            "dbo.usp_Product_Update", p, commandType: CommandType.StoredProcedure, cancellationToken: ct));
    }

    public async Task DeleteAsync(int productId, CancellationToken ct)
    {
        using var con = _factory.Create();
        var p = new DynamicParameters();
        p.Add("@ProductId", productId, DbType.Int32);

        await con.ExecuteAsync(new CommandDefinition(
            "dbo.usp_Product_Delete", p, commandType: CommandType.StoredProcedure, cancellationToken: ct));
    }

    public async Task<IReadOnlyList<ProductReadDto>> ListAsync(CancellationToken ct)
    {
        using var con = _factory.Create();
        var rows = await con.QueryAsync<ProductReadDto>(new CommandDefinition(
            "dbo.usp_Products_ListInventory", commandType: CommandType.StoredProcedure, cancellationToken: ct));
        return rows.ToList();
    }

    public async Task<ProductReadDto?> GetByIdAsync(int productId, CancellationToken ct)
    {
        using var con = _factory.Create();
        // Simple select for detail (SP not required here)
        var row = await con.QueryFirstOrDefaultAsync<ProductReadDto>(new CommandDefinition(@"
            SELECT ProductId, Name, Price, Stock, ImageUrl, IsActive
            FROM dbo.Product WHERE ProductId = @ProductId",
            new { ProductId = productId }, cancellationToken: ct));
        return row;
    }
}

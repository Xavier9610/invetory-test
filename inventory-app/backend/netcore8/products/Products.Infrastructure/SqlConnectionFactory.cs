using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Products.Infrastructure;

public sealed class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("InventoryDb")
            ?? throw new InvalidOperationException("Missing connection string 'InventoryDb'.");
    }

    public IDbConnection Create() => new SqlConnection(_connectionString);
}

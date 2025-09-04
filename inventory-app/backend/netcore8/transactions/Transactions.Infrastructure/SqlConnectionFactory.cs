using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Transactions.Infrastructure;

public sealed class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _cnn;

    public SqlConnectionFactory(IConfiguration cfg)
    {
        _cnn = cfg.GetConnectionString("InventoryDb")
            ?? throw new InvalidOperationException("Missing connection string 'InventoryDb'.");
    }

    public IDbConnection Create() => new SqlConnection(_cnn);
}

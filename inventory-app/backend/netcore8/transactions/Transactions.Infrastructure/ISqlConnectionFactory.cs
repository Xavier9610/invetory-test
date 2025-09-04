using System.Data;

namespace Transactions.Infrastructure;

public interface ISqlConnectionFactory
{
    IDbConnection Create();
}

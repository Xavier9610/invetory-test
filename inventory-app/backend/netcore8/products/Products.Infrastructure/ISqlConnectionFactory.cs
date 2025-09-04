using System.Data;

namespace Products.Infrastructure;

public interface ISqlConnectionFactory
{
    IDbConnection Create();
}

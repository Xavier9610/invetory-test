using Transactions.Application.Dtos;

namespace Transactions.Infrastructure;

public interface ITransactionRepository
{
    Task<long> AddAsync(TransactionCreateDto dto, CancellationToken ct);
    Task UpdateAsync(long id, TransactionUpdateDto dto, CancellationToken ct);
    Task DeleteAsync(long id, CancellationToken ct);

    Task<TransactionReadDto?> GetByIdAsync(long id, CancellationToken ct);
    Task<PagedResult<TransactionReadDto>> SearchAsync(
        int? productId, byte? typeId, DateTime? startUtc, DateTime? endUtc,
        int page, int pageSize, CancellationToken ct);
}

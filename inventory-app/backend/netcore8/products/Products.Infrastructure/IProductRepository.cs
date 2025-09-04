using Products.Application.Dtos;

namespace Products.Infrastructure;

public interface IProductRepository
{
    Task<int> AddAsync(ProductCreateDto dto, CancellationToken ct);
    Task UpdateAsync(int productId, ProductUpdateDto dto, CancellationToken ct);
    Task DeleteAsync(int productId, CancellationToken ct);
    Task<IReadOnlyList<ProductReadDto>> ListAsync(CancellationToken ct);
    Task<ProductReadDto?> GetByIdAsync(int productId, CancellationToken ct);
}

namespace Products.Application.Dtos{
// DTOs for API <-> Application (input/output)

public class ProductReadDto
{
    public int ProductId { get; set; }
    public string Name { get; set; } = default!;
    public decimal Price { get; set; }
    public int Stock { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; }
}
}

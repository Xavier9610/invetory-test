namespace Products.Domain;

public sealed class Product
{
    //DB Model
    public int ProductId { get; set; }
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public decimal Price { get; set; }
    public int Stock { get; set; }
    public bool IsActive { get; set; }
}

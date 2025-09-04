namespace Products.Application.Dtos
{

    // DTOs for API <-> Application (input/output)

    public sealed class ProductUpdateDto
    {
        public string Name { get; set; } = default!;
        public string? Description { get; set; }
        public string? ImageUrl { get; set; }
        public decimal Price { get; set; }
        public bool IsActive { get; set; } = true;
    }

}